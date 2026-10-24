# AWS への公開と、ふだんの操作

公開用のサーバーを AWS(東京リージョン)に作り、運用するための手順です。ソースは `deploy/aws/` にあります。
アプリの設定・メール(SES)・バックアップの中身は [本番運用の手順](本番運用.md) にあります。

## 作られるもの(すべて Project=recipebook のタグ付き)

| 資源 | 内容 |
|---|---|
| EC2 | t4g.micro(メモリ 1GB)、Amazon Linux 2023、ディスク 20GB(暗号化)。SSH は使わず、SSM で操作する |
| Elastic IP | 固定の IP アドレス。止めて起動しても公開アドレスが変わらない |
| セキュリティグループ `recipebook-web` | 80・443 番だけを開ける(22 番は開けない) |
| IAM ロール `recipebook-ec2` | SSM での操作、バックアップ用バケットの読み書き、`/recipebook/` のパラメータの読み出しだけ |
| S3 バケット `recipebook-backup-<アカウントID>` | バックアップ用。公開を全部ブロック、暗号化、30日で自動削除 |
| Parameter Store `/recipebook/*` | SMTP のユーザー名・パスワード、送信元のアドレス(SecureString)。手で登録する |

公開アドレスは `https://<IPアドレスの . を - に変えたもの>.sslip.io/` です。証明書(Let's Encrypt)は自動で取得されます。

## 最初に1回だけ

1. AWS にログインする(IAM Identity Center。ルートユーザーは使わない): `aws sso login --profile taskboard`
2. SES で送信元のアドレスを認証し(東京)、SMTP 認証情報を作る
3. Parameter Store(東京)に、`/recipebook/smtp_username`・`/recipebook/smtp_password`・`/recipebook/mail_from` を SecureString で登録する
4. 資源を作る: `pwsh .\deploy\aws\setup.ps1`(すでにあるものは作り直さない。何度実行しても安全)
5. サーバーの中の準備(Docker のインストール・イメージの作成)に 10 分ほどかかる。進み具合は `server.ps1 log`
6. 会員登録をして、`server.ps1 grant-admin -Email 登録したアドレス` で管理者にする

## ふだんの操作(`pwsh .\deploy\aws\server.ps1 <操作>`)

| 操作 | 内容 |
|---|---|
| `status` | 状態と公開アドレスを表示 |
| `health` | メモリ・コンテナごとのメモリ・ディスク・次のバックアップの予定 |
| `log` | サーバーの準備の記録と、アプリのログの終わり |
| `update` | **main の最新を反映する**。先にバックアップを取り、git pull、イメージの作り直し、再起動の順に行う |
| `backup` | 今すぐバックアップを取る(サーバーに保存し、S3 にも送る) |
| `grant-admin -Email …` | 会員を管理者にする |
| `mail-test` | 送信元のアドレス宛てに、テストのメールを1通送る |
| `stop` / `start` | 止める / 起動する(IP アドレスは変わらない) |

## 費用の目安(東京。実際の金額は AWS の料金ページと請求画面で確認する)

- EC2・ディスク・公開 IPv4 アドレス・S3 で、動かしている間は月に 2,000 円前後
- `stop` で止めている間は EC2 の分がかからない。Elastic IP とディスクの分は少しかかる
- 使わなくなったら、EC2 を終了し、Elastic IP を解放し、S3 のバケットを空にして削除する(Elastic IP は、使っていなくても料金がかかる)

## 困ったとき

- **ページが開かない**: `status` で状態を見る。`log` でコンテナが `healthy` か確かめる。作りたての間は 10 分ほど待つ
- **メールが届かない**: `mail-test` を試す。SES が「サンドボックス」のままだと、認証したアドレス以外には送れない(解除の申請が必要)
- **ログインの期限切れ**(`Token has expired`): `aws sso login --profile taskboard` をもう一度実行する
- **バックアップから戻す**: [本番運用の手順](本番運用.md) の「戻す(リストア)」。サーバーの中のバックアップは `/var/backups/recipebook/`、S3 は `s3://<バケット>/recipebook/`
