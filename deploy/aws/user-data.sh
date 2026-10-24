#!/bin/bash
# EC2(Amazon Linux 2023・arm64)を最初に起動したときに1回だけ動く準備。
# Docker を入れ、GitHub からアプリを取得し、本番用の compose で起動する。
# __SITE_ADDRESS__ と __BACKUP_BUCKET__ は、setup.ps1 が実際の値に置き換えてから EC2 に渡す。
# このファイルに秘密の値は書かない(SMTP は Parameter Store から、DB のパスワードはサーバーの中で作る)。
# 経過は /var/log/recipebook-setup.log に残る。2回目以降の起動では、Docker とコンテナが自動で立ち上がる。
set -eu -o pipefail
exec > >(tee -a /var/log/recipebook-setup.log) 2>&1

SITE_ADDRESS="__SITE_ADDRESS__"
BACKUP_BUCKET="__BACKUP_BUCKET__"
APP_DIR=/opt/recipebook
export AWS_DEFAULT_REGION=ap-northeast-1

step() { echo "[$(date '+%F %T')] $*"; }

step "1. スワップ(メモリ 1GB でもイメージを作れるように、2GB の予備)"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

step "2. Docker と git"
dnf install -y docker git
command -v aws >/dev/null || dnf install -y awscli-2 || dnf install -y awscli
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{ "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
JSON
systemctl enable --now docker

# docker compose(Amazon Linux の docker には入っていないので、公式の配布物を入れる)
mkdir -p /usr/local/lib/docker/cli-plugins
curl -fsSL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

step "3. アプリを取得(公開リポジトリの main)"
if [ ! -d "$APP_DIR" ]; then
  git clone --depth 1 https://github.com/123tk555-gif/recipebook.git "$APP_DIR"
fi
cd "$APP_DIR"

step "4. 設定ファイル(.env)を作る"
if [ ! -f .env ]; then
  umask 077
  param() { aws ssm get-parameter --name "/recipebook/$1" --with-decryption --query Parameter.Value --output text 2>/dev/null || true; }
  SMTP_USERNAME=$(param smtp_username)
  SMTP_PASSWORD=$(param smtp_password)
  MAIL_FROM=$(param mail_from)
  {
    # データベースのパスワードと Rails の秘密鍵は、このサーバーの中でランダムに作り、外には出さない
    echo "DB_ROOT_PASSWORD=$(openssl rand -hex 24)"
    echo "DB_PASSWORD=$(openssl rand -hex 24)"
    echo "SECRET_KEY_BASE=$(openssl rand -hex 64)"
    echo "APP_HOST=$SITE_ADDRESS"
    echo "SITE_ADDRESS=$SITE_ADDRESS"
    echo "BACKUP_S3_BUCKET=$BACKUP_BUCKET"
    if [ -n "$SMTP_USERNAME" ] && [ -n "$SMTP_PASSWORD" ] && [ -n "$MAIL_FROM" ]; then
      echo "SMTP_ADDRESS=email-smtp.ap-northeast-1.amazonaws.com"
      echo "SMTP_PORT=587"
      echo "SMTP_USERNAME=$SMTP_USERNAME"
      echo "SMTP_PASSWORD=$SMTP_PASSWORD"
      echo "MAIL_FROM=$MAIL_FROM"
    fi
  } > .env
  if grep -q '^SMTP_ADDRESS=' .env; then step "   メール(SES)の設定を読み込みました"; else step "   注意: Parameter Store に /recipebook/ の SMTP 設定が無いので、メールは送られません"; fi
fi

step "5. イメージを作って起動する(数分かかります)"
docker build -t recipebook-app .
docker compose -f compose.prod.yaml up -d

step "6. 毎日のバックアップ(systemd のタイマー)"
cp deploy/backup/recipebook-backup.service deploy/backup/recipebook-backup.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now recipebook-backup.timer

step "7. 起動の確認"
for i in $(seq 1 60); do
  status=$(docker inspect -f '{{.State.Health.Status}}' recipebook-prod-app-1 2>/dev/null || echo none)
  [ "$status" = "healthy" ] && break
  sleep 5
done
step "   アプリの状態: $status"
step "recipebook: 準備が終わりました(https://$SITE_ADDRESS/)"
