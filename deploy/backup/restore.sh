#!/bin/bash
# バックアップから戻す(データベースと画像を、バックアップの時点に置き換える)。
#   使い方: deploy/backup/restore.sh /var/backups/recipebook/20261019-033000
#           deploy/backup/restore.sh s3://<バケット>/recipebook/20261019-033000
#   確認を省くとき(自動の試験など)は、最後に --yes を付ける
# 戻している間は、アプリと入口(Caddy)を止める。データベースのコンテナは動かしたまま。
set -euo pipefail
# Windows の Git Bash で試すとき、コンテナの中のパス(/rails/storage など)が書き換えられないようにする
export MSYS_NO_PATHCONV=1

src=${1:?使い方: restore.sh <バックアップのフォルダ または s3://...> [--yes]}
yes=${2:-}

cd "$(dirname "$0")/../.."
ENV_FILE=${ENV_FILE:-.env}
COMPOSE=(docker compose -f compose.prod.yaml --env-file "$ENV_FILE")

work=$src
if [[ "$src" == s3://* ]]; then
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  aws s3 cp --recursive --only-show-errors "$src" "$work"
fi

# 1. 壊れていないかを確かめる
(cd "$work" && sha256sum -c --quiet SHA256SUMS)
echo "バックアップ: $src(チェックサム OK)"

if [ "$yes" != "--yes" ]; then
  echo "今のデータベースと画像は、すべてこのバックアップの内容に置き換わります(元に戻せません)。"
  read -r -p "続けるなら restore と入力してください: " answer
  [ "$answer" = "restore" ] || { echo "やめました"; exit 1; }
fi

"${COMPOSE[@]}" stop caddy app

# 2. データベースを作り直して流し込む(ダンプには CREATE DATABASE が入っている)
"${COMPOSE[@]}" exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -e "DROP DATABASE IF EXISTS recipebook_production"'
zcat "$work/db.sql.gz" | "${COMPOSE[@]}" exec -T db sh -c 'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysql -uroot'

# 3. 画像を入れ替える(アプリと同じユーザーで展開する)
"${COMPOSE[@]}" run --rm --no-deps -T --entrypoint "" app \
  sh -c 'find /rails/storage -mindepth 1 -delete && tar -C /rails/storage -xzf -' < "$work/storage.tar.gz"

"${COMPOSE[@]}" up -d app caddy
echo "戻しました。アプリを起動しています(1分ほどで使えるようになります)。"
