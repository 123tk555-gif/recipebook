#!/bin/bash
# データベースと画像をバックアップする(サーバーで毎日実行。deploy/backup/recipebook-backup.timer)。
#   使い方: deploy/backup/backup.sh
#   保存先: $BACKUP_DIR/<日時>/(既定は /var/backups/recipebook)。古いものは $BACKUP_KEEP_DAYS 日(既定 7)で消す
#   .env に BACKUP_S3_BUCKET があれば、S3 の s3://<バケット>/recipebook/<日時>/ にも送る
#   (S3 側の保存期間は、バケットのライフサイクルルールで決める。30日)
# 含めるもの: 本体のデータベース(recipebook_production)と画像(storage)。
# キャッシュ・ジョブ・リアルタイム通信用のデータベースは作り直せるので含めない。
set -euo pipefail
# Windows の Git Bash で試すとき、コンテナの中のパス(/rails/storage など)が書き換えられないようにする
export MSYS_NO_PATHCONV=1

cd "$(dirname "$0")/../.."
ENV_FILE=${ENV_FILE:-.env}
COMPOSE=(docker compose -f compose.prod.yaml --env-file "$ENV_FILE")
DEST_ROOT=${BACKUP_DIR:-/var/backups/recipebook}
KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}
# .env を丸ごと読み込まず、使う値だけを取り出す
BUCKET=$(grep -E '^BACKUP_S3_BUCKET=' "$ENV_FILE" | tail -1 | cut -d= -f2- || true)

stamp=$(date +%Y%m%d-%H%M%S)
dest="$DEST_ROOT/$stamp"
umask 077
mkdir -p "$dest"

echo "[$(date '+%F %T')] バックアップを始めます: $dest"

# 1. データベース(書き込みを止めずに、整合性のとれた状態でダンプする)
"${COMPOSE[@]}" exec -T db sh -c \
  'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot --single-transaction --quick --routines --triggers \
     --set-gtid-purged=OFF --databases recipebook_production' | gzip > "$dest/db.sql.gz"

# 2. 画像(Active Storage の保存先)
"${COMPOSE[@]}" exec -T app tar -C /rails/storage -czf - . > "$dest/storage.tar.gz"

# 3. 壊れていないかを確かめ、チェックサムを残す
gzip -t "$dest/db.sql.gz"
zcat "$dest/db.sql.gz" | tail -1 | grep -q "Dump completed" || { echo "ダンプが最後まで書けていません" >&2; exit 1; }
tar -tzf "$dest/storage.tar.gz" > /dev/null
(cd "$dest" && sha256sum db.sql.gz storage.tar.gz > SHA256SUMS)
echo "  データベース: $(du -h "$dest/db.sql.gz" | cut -f1) / 画像: $(du -h "$dest/storage.tar.gz" | cut -f1)"

# 4. S3 に送る(サーバーに付けた IAM ロールの権限で送る。鍵はサーバーに置かない)
if [ -n "$BUCKET" ]; then
  aws s3 cp --recursive --only-show-errors "$dest" "s3://$BUCKET/recipebook/$stamp/"
  echo "  S3 に送りました: s3://$BUCKET/recipebook/$stamp/"
else
  echo "  BACKUP_S3_BUCKET が未設定なので、S3 には送りません"
fi

# 5. サーバーの中の古いバックアップを消す
find "$DEST_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' -mtime "+$KEEP_DAYS" -exec rm -rf {} +

echo "[$(date '+%F %T')] バックアップが終わりました"
