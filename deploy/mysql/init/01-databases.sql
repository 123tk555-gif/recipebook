-- 最初にデータベースを作るときに1回だけ実行される。
-- 本番は4つのデータベースを使う(本体・キャッシュ・ジョブ・リアルタイム通信)。
-- アプリのユーザー(recipebook。compose.prod.yaml の MYSQL_USER で作られる)に、この4つだけの権限を付ける。
CREATE DATABASE IF NOT EXISTS recipebook_production CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS recipebook_production_cache CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS recipebook_production_queue CHARACTER SET utf8mb4;
CREATE DATABASE IF NOT EXISTS recipebook_production_cable CHARACTER SET utf8mb4;
GRANT ALL PRIVILEGES ON `recipebook\_production`.* TO 'recipebook'@'%';
GRANT ALL PRIVILEGES ON `recipebook\_production\_cache`.* TO 'recipebook'@'%';
GRANT ALL PRIVILEGES ON `recipebook\_production\_queue`.* TO 'recipebook'@'%';
GRANT ALL PRIVILEGES ON `recipebook\_production\_cable`.* TO 'recipebook'@'%';
FLUSH PRIVILEGES;
