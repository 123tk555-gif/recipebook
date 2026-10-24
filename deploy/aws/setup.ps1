# AWS に公開用の環境を作る(最初に1回だけ)。何度実行しても、すでにあるものは作り直さない。
#   使い方: aws sso login --profile taskboard のあとで  pwsh .\deploy\aws\setup.ps1
# 作るもの(すべて東京リージョン。タグ Project=recipebook):
#   S3 バケット(バックアップ用・30日で消える) / IAM ロール / セキュリティグループ(80・443 のみ)
#   Elastic IP(固定の IP アドレス) / EC2 t4g.micro(メモリ 1GB、ディスク 20GB・暗号化)
# 事前に、Parameter Store に /recipebook/smtp_username・smtp_password・mail_from(SecureString)を入れておく。
# PowerShell 7 で実行する。
$ErrorActionPreference = 'Stop'
$Profile_ = 'taskboard'
$Region = 'ap-northeast-1'
$here = $PSScriptRoot

$aws = (Get-Command aws -ErrorAction SilentlyContinue).Source
if (-not $aws) { $aws = 'C:\Program Files\Amazon\AWSCLIV2\aws.exe' }

# aws を呼ぶ。失敗したら止める。JSON が返れば、オブジェクトにして返す
function Invoke-Aws {
    $out = & $aws @args --profile $Profile_ --region $Region --output json
    if ($LASTEXITCODE -ne 0) { throw "aws $($args -join ' ') が失敗しました" }
    if ($out) { ($out | Out-String) | ConvertFrom-Json }
}
# 「無ければ作る」ために、失敗してもよい呼び出し(あるかどうかの確認)
function Test-Aws {
    $null = & $aws @args --profile $Profile_ --region $Region --output json 2>$null
    $LASTEXITCODE -eq 0
}
function Step($text) { Write-Host ''; Write-Host "== $text" -ForegroundColor Cyan }
function Write-Temp($text) {
    $f = Join-Path ([IO.Path]::GetTempPath()) "recipebook-$([guid]::NewGuid().ToString('N')).json"
    [IO.File]::WriteAllText($f, $text, (New-Object Text.UTF8Encoding $false))
    $f
}
$tag = 'Key=Project,Value=recipebook'

$account = (Invoke-Aws sts get-caller-identity).Account
$bucket = "recipebook-backup-$account"
Write-Host "アカウントにログインできました(バケット名: $bucket)"

# ---------------------------------------------------------------- 1. S3
Step '1. S3 バケット(バックアップ用)'
if (Test-Aws s3api head-bucket --bucket $bucket) {
    Write-Host '   すでにあります'
} else {
    Invoke-Aws s3api create-bucket --bucket $bucket --create-bucket-configuration "LocationConstraint=$Region" | Out-Null
    Write-Host '   作りました'
}
Invoke-Aws s3api put-public-access-block --bucket $bucket `
    --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true' | Out-Null
Invoke-Aws s3api put-bucket-encryption --bucket $bucket `
    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' | Out-Null
$lifecycle = Write-Temp '{"Rules":[{"ID":"expire-backups-30d","Status":"Enabled","Filter":{"Prefix":"recipebook/"},"Expiration":{"Days":30},"AbortIncompleteMultipartUpload":{"DaysAfterInitiation":7}}]}'
try { Invoke-Aws s3api put-bucket-lifecycle-configuration --bucket $bucket --lifecycle-configuration "file://$lifecycle" | Out-Null } finally { [IO.File]::Delete($lifecycle) }
Invoke-Aws s3api put-bucket-tagging --bucket $bucket --tagging 'TagSet=[{Key=Project,Value=recipebook}]' | Out-Null
Write-Host '   公開を全部ブロック・暗号化・30日で自動削除 を設定しました'

# ---------------------------------------------------------------- 2. IAM
Step '2. IAM ロール(EC2 に付ける権限)'
$role = 'recipebook-ec2'
if (Test-Aws iam get-role --role-name $role) {
    Write-Host '   ロールはすでにあります'
} else {
    Invoke-Aws iam create-role --role-name $role --assume-role-policy-document "file://$here\ec2-trust-policy.json" `
        --description 'recipebook EC2: SSM, the backup S3 bucket, and /recipebook/ parameters only' --tags $tag | Out-Null
    Write-Host '   ロールを作りました'
}
Invoke-Aws iam attach-role-policy --role-name $role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore | Out-Null
$policy = (Get-Content "$here\ec2-policy.json" -Raw -Encoding UTF8).Replace('__BUCKET__', $bucket).Replace('__ACCOUNT__', $account)
$policyFile = Write-Temp $policy
try { Invoke-Aws iam put-role-policy --role-name $role --policy-name recipebook-app --policy-document "file://$policyFile" | Out-Null } finally { [IO.File]::Delete($policyFile) }
if (-not (Test-Aws iam get-instance-profile --instance-profile-name $role)) {
    Invoke-Aws iam create-instance-profile --instance-profile-name $role --tags $tag | Out-Null
    Invoke-Aws iam add-role-to-instance-profile --instance-profile-name $role --role-name $role | Out-Null
    Write-Host '   インスタンスプロファイルを作りました(反映まで少し待ちます)'
    Start-Sleep -Seconds 15
}
Write-Host '   権限: SSM での操作 / バックアップ用バケットの読み書き / /recipebook/ のパラメータの読み出しだけ'

# ---------------------------------------------------------------- 3. セキュリティグループ
Step '3. セキュリティグループ(80・443 番だけを開ける。SSH は開けない)'
$vpc = (Invoke-Aws ec2 describe-vpcs --filters "Name=isDefault,Values=true").Vpcs[0].VpcId
$sg = (Invoke-Aws ec2 describe-security-groups --filters "Name=group-name,Values=recipebook-web" "Name=vpc-id,Values=$vpc").SecurityGroups
if ($sg.Count -eq 0) {
    $sgId = (Invoke-Aws ec2 create-security-group --group-name recipebook-web --description 'recipebook: HTTP and HTTPS only' --vpc-id $vpc `
            --tag-specifications 'ResourceType=security-group,Tags=[{Key=Project,Value=recipebook},{Key=Name,Value=recipebook-web}]').GroupId
    foreach ($port in 80, 443) {
        Invoke-Aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port $port --cidr 0.0.0.0/0 | Out-Null
    }
    Write-Host "   作りました($sgId)"
} else {
    $sgId = $sg[0].GroupId
    Write-Host "   すでにあります($sgId)"
}

# ---------------------------------------------------------------- 4. Elastic IP
Step '4. Elastic IP(止めて起動しても変わらない IP アドレス)'
$eip = (Invoke-Aws ec2 describe-addresses --filters "Name=tag:Project,Values=recipebook").Addresses
if ($eip.Count -eq 0) {
    $eip = Invoke-Aws ec2 allocate-address --domain vpc --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Project,Value=recipebook},{Key=Name,Value=recipebook}]'
    $allocId = $eip.AllocationId; $ip = $eip.PublicIp
    Write-Host "   取得しました($ip)"
} else {
    $allocId = $eip[0].AllocationId; $ip = $eip[0].PublicIp
    Write-Host "   すでにあります($ip)"
}
$site = ($ip -replace '\.', '-') + '.sslip.io'

# ---------------------------------------------------------------- 5. EC2
Step '5. EC2(t4g.micro・メモリ 1GB)'
$existing = (Invoke-Aws ec2 describe-instances --filters "Name=tag:Project,Values=recipebook" `
        "Name=instance-state-name,Values=pending,running,stopping,stopped").Reservations.Instances
if ($existing.Count -gt 0) {
    $id = $existing[0].InstanceId
    Write-Host "   すでにあります($id)"
} else {
    $ami = (Invoke-Aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64).Parameter.Value
    $userData = (Get-Content "$here\user-data.sh" -Raw -Encoding UTF8).Replace("`r`n", "`n").Replace('__SITE_ADDRESS__', $site).Replace('__BACKUP_BUCKET__', $bucket)
    $udFile = Write-Temp $userData
    $subnet = (Invoke-Aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" "Name=availability-zone,Values=ap-northeast-1a").Subnets[0].SubnetId
    try {
        $run = Invoke-Aws ec2 run-instances --image-id $ami --instance-type t4g.micro --subnet-id $subnet --security-group-ids $sgId `
            --iam-instance-profile Name=$role --user-data "fileb://$udFile" --metadata-options 'HttpTokens=required,HttpPutResponseHopLimit=2' `
            --block-device-mappings 'DeviceName=/dev/xvda,Ebs={VolumeSize=20,VolumeType=gp3,Encrypted=true,DeleteOnTermination=true}' `
            --tag-specifications 'ResourceType=instance,Tags=[{Key=Project,Value=recipebook},{Key=Name,Value=recipebook}]' 'ResourceType=volume,Tags=[{Key=Project,Value=recipebook}]'
    } finally { [IO.File]::Delete($udFile) }
    $id = $run.Instances[0].InstanceId
    Write-Host "   起動しました($id)"
}
& $aws ec2 wait instance-running --instance-ids $id --profile $Profile_ --region $Region
if ($LASTEXITCODE -ne 0) { throw '起動の確認に失敗しました' }
Invoke-Aws ec2 associate-address --instance-id $id --allocation-id $allocId | Out-Null
Write-Host "   Elastic IP($ip)を結び付けました"

Write-Host ''
Write-Host '完了しました。' -ForegroundColor Green
Write-Host "  公開アドレス:   https://$site/"
Write-Host "  インスタンス:   $id"
Write-Host "  バックアップ先: s3://$bucket/recipebook/"
Write-Host '  サーバーの中の準備(Docker のインストール・イメージの作成)に 10 分ほどかかります。'
Write-Host '  できあがるまで、上のアドレスは開けません。'
