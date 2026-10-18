# レシピ管理アプリ

レシピを登録・検索・共有できる Web アプリです。会員はレシピの投稿、お気に入り、買い物リスト、献立が使えます。
詳しくは [要件定義書](要件定義書.md) を見てください。

## 使っている技術

| 部分 | 技術 |
|---|---|
| サーバー・画面 | Ruby 4.0.7、Ruby on Rails 8.1.4(Hotwire: Turbo + Stimulus、ERB) |
| データベース | MySQL 9.7(Docker で動かす) |
| テスト | Minitest(Rails 標準) |

## 動かし方(開発)

PC に Ruby は要りません。Docker Desktop だけで動きます(Ruby も MySQL もコンテナの中)。

```sh
docker compose up -d            # アプリとデータベースを起動 → http://localhost:3000
docker compose logs -f web      # ログを見る
docker compose down             # 止める(データは残る)
```

よく使うコマンド(起動中のコンテナで実行):

```sh
docker compose exec web bin/rails test        # テスト
docker compose exec web bin/rubocop           # コードの書き方のチェック
docker compose exec web bin/brakeman          # 安全面のチェック
docker compose exec web bin/rails db:migrate  # データベースの変更を反映
docker compose exec web bin/rails console     # Rails のコンソール
```

## 注意

- `config/master.key` は git に入れていません。本番の公開に必要なので、なくさないよう保管してください。
- テストは並列実行していません(Ruby 4.0.7 + trilogy ではスレッド並列にすると接続が衝突するため)。
