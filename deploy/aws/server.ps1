# 公開用のサーバー(EC2)の操作。
#   使い方: aws sso login --profile taskboard のあとで
#     pwsh .\deploy\aws\server.ps1 status   # 状態と公開アドレスを表示
#     pwsh .\deploy\aws\server.ps1 stop     # 止める(EC2 の料金がかからなくなる。データは残る)
#     pwsh .\deploy\aws\server.ps1 start    # 起動する(IP アドレスは変わらない)
#     pwsh .\deploy\aws\server.ps1 update   # main の最新を取り込んで作り直す(先にバックアップを取る)
#     pwsh .\deploy\aws\server.ps1 backup   # 今すぐバックアップを取る
#     pwsh .\deploy\aws\server.ps1 log      # サーバーの準備の記録と、アプリのログの終わりを表示
#     pwsh .\deploy\aws\server.ps1 health   # メモリ・ディスク・次のバックアップの予定を表示
#     pwsh .\deploy\aws\server.ps1 grant-admin -Email 登録済みのアドレス   # 会員を管理者にする
param(
    [Parameter(Mandatory)][ValidateSet('status', 'start', 'stop', 'update', 'backup', 'log', 'health', 'grant-admin', 'mail-test')][string]$Action,
    [string]$Email
)
$ErrorActionPreference = 'Stop'
# Windows の既定の文字コード(Shift_JIS)だと、AWS CLI の返す日本語が壊れて JSON として読めなくなる。UTF-8 にそろえる
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'
$Profile_ = 'taskboard'
$Region = 'ap-northeast-1'
$aws = (Get-Command aws -ErrorAction SilentlyContinue).Source
if (-not $aws) { $aws = 'C:\Program Files\Amazon\AWSCLIV2\aws.exe' }

function Invoke-Aws {
    $out = & $aws @args --profile $Profile_ --region $Region --output json
    if ($LASTEXITCODE -ne 0) { throw "aws $($args -join ' ') が失敗しました" }
    if ($out) { ($out | Out-String) | ConvertFrom-Json }
}

$inst = (Invoke-Aws ec2 describe-instances --filters "Name=tag:Project,Values=recipebook" `
        "Name=instance-state-name,Values=pending,running,stopping,stopped").Reservations.Instances
if ($inst.Count -eq 0) { throw 'recipebook のサーバーが見つかりません(先に setup.ps1 を実行してください)' }
$id = $inst[0].InstanceId

# サーバーの中でコマンドを実行して、結果を表示する(SSH は使わない。SSM 経由)
function Invoke-OnServer([string[]]$commands) {
    $json = @{ commands = $commands; executionTimeout = @('1800') } | ConvertTo-Json -Compress
    # 日本語を \uXXXX に直して、ASCII だけのファイルにする(Windows の AWS CLI は、日本語入りのファイルを読めないため)
    $json = [regex]::Replace($json, '[^\x00-\x7F]', { param($m) '\u{0:x4}' -f [int][char]$m.Value })
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "recipebook-ssm-$([guid]::NewGuid().ToString('N')).json"
    [IO.File]::WriteAllText($tmp, $json, (New-Object Text.UTF8Encoding $false))
    try { $cmdId = (Invoke-Aws ssm send-command --instance-ids $id --document-name AWS-RunShellScript --parameters "file://$tmp").Command.CommandId }
    finally { [IO.File]::Delete($tmp) }
    for ($i = 0; $i -lt 360; $i++) {
        Start-Sleep -Seconds 5
        $r = Invoke-Aws ssm get-command-invocation --command-id $cmdId --instance-id $id
        if ($r.Status -in 'Success', 'Failed', 'Cancelled', 'TimedOut') { break }
    }
    Write-Host $r.StandardOutputContent
    if ($r.StandardErrorContent) { Write-Host $r.StandardErrorContent -ForegroundColor Yellow }
    if ($r.Status -ne 'Success') { throw "サーバーでの実行が終わりませんでした(状態: $($r.Status))" }
}

$app = 'cd /opt/recipebook'
switch ($Action) {
    'status' {
        $i = (Invoke-Aws ec2 describe-instances --instance-ids $id).Reservations.Instances[0]
        $ip = $i.PublicIpAddress
        Write-Host "インスタンス: $id / 状態: $($i.State.Name) / IP: $ip"
        if ($ip) { Write-Host "公開アドレス: https://$($ip -replace '\.', '-').sslip.io/" }
    }
    'start' {
        Invoke-Aws ec2 start-instances --instance-ids $id | Out-Null
        & $aws ec2 wait instance-running --instance-ids $id --profile $Profile_ --region $Region
        Write-Host '起動しました。アプリが立ち上がるまで 1〜2 分かかります。'
    }
    'stop' {
        Invoke-Aws ec2 stop-instances --instance-ids $id | Out-Null
        Write-Host '止めました(EC2 の料金はかからなくなります。Elastic IP とディスクの分は少しかかります)。'
    }
    'update' {
        Invoke-OnServer @($app, 'set -e', 'deploy/backup/backup.sh', 'git pull --ff-only', 'docker build -t recipebook-app .',
            'docker compose -f compose.prod.yaml up -d', 'docker image prune -f', 'docker compose -f compose.prod.yaml ps')
    }
    'backup' { Invoke-OnServer @($app, 'deploy/backup/backup.sh', 'ls -la /var/backups/recipebook | tail -5') }
    'log' {
        Invoke-OnServer @('tail -n 25 /var/log/recipebook-setup.log', 'echo ---', "$app && docker compose -f compose.prod.yaml ps", 'echo ---',
            "$app && docker compose -f compose.prod.yaml logs --tail 20 app", 'echo ---', 'free -m | head -2')
    }
    'health' {
        Invoke-OnServer @('echo "--- メモリ(MB)"', 'free -m', 'echo "--- コンテナごとのメモリ"', 'docker stats --no-stream --format "{{.Name}} {{.MemUsage}}"',
            'echo "--- ディスク"', 'df -h / | tail -1', 'echo "--- 次のバックアップの予定"', 'systemctl list-timers recipebook-backup.timer --no-pager | head -3')
    }
    'mail-test' {
        # 送信元(MAIL_FROM)のアドレス宛てに1通だけ送る。SES のサンドボックス中でも、検証済みのアドレス宛てなら送れる
        $ruby = 'ActionMailer::Base.mail(from: ENV["MAIL_FROM"], to: ENV["MAIL_FROM"], subject: "【レシピ管理】メール送信のテスト", body: "このメールは、本番サーバーからの送信テストです。心当たりがなければ、無視してください。").deliver_now; puts "送信しました"'
        Invoke-OnServer @($app, "docker compose -f compose.prod.yaml exec -T app bin/rails runner '$ruby'")
    }
    'grant-admin' {
        # メールアドレスはサーバーの中のコマンドに入るので、使える文字を絞って、おかしな文字列を通さない
        if ($Email -notmatch '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') { throw '-Email に、登録済みのメールアドレスを指定してください' }
        Invoke-OnServer @($app, "docker compose -f compose.prod.yaml exec -T app bin/rails 'admin:grant[$Email]'")
    }
}
