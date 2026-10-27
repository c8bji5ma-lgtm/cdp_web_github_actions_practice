# Docker Blog

タイトルと本文を登録・表示・更新・削除するRailsブログです。

## バージョンと構成

- Ruby 4.0.6 / Rails 8.1.3
- PostgreSQL 15
- Docker ComposeでRails（web）とPostgreSQL（db）を起動
- 本番DBは`postgres_data` volumeへ永続化。DBのポートは公開しません。
- scaffoldを使用。タイトルと本文は必須で、同じタイトルの複数投稿を許可します。

## ローカルで起動

Docker EngineとDocker Composeを用意し、このディレクトリで実行します。

```bash
cp .env.example .env
```

`.env`の`POSTGRES_PASSWORD`と`SECRET_KEY_BASE`には、それぞれ`openssl rand -hex 32`、`openssl rand -hex 64`等で作成した別々のランダム値を設定してください。`.env`と`config/master.key`はGit・Dockerイメージへ含めません。

```bash
docker compose up -d --build --wait
```

http://localhost:3000/ を開きます。起動時に`db:prepare`が実行されます。

```bash
docker compose down
```

通常の`down`ではDBを保持します。`down --volumes`はDBを削除するため使用しないでください。

## 検証

```bash
docker compose run --rm -e RAILS_ENV=test web ./bin/rails db:prepare test
docker compose exec -T web ./bin/rails zeitwerk:check
curl --fail http://localhost:3000/up
```

テストDBは本番DBと別名の`docker_blog_test`です。テストではHTTPリクエストを通したCRUD、保存値、空の一覧、必須入力、同名投稿の独立性を確認します。

永続化は、記事を1件作成した後に次を実行し、同じ記事が表示されることで確認できます。

```bash
docker compose up -d --force-recreate --wait
```

## EC2に配備

新規作成用のCloudFormationテンプレートは`deploy/ec2.json`です。ARMの`t4g.small` 1台（T4g無料トライアルを利用）、暗号化gp3 8 GiB、Elastic IP 1個、HTTPと作業元IPだけのSSHを設定します。既存VPCとインターネットゲートウェイへの経路を持つ公開サブネット、およびSSH公開鍵をパラメーターで指定します。CPUクレジットは`standard`です。インスタンスを終了するとルートディスク内のDBも削除されます。

EC2上の専用フォルダーを使用し、Docker EngineとDocker Composeを用意します。AWSリソースの作成には、利用するアカウントと構成・費用の確認が必要です。

T4g無料トライアルは2027年1月1日09:00（日本時間）まで、全リージョン合計で月750時間が対象です。EBSとElastic IPは別料金で、利用可能なAWSクレジットがある場合は残高から充当されます。トライアル終了後は通常料金になります。適用条件は[AWS公式FAQ](https://aws.amazon.com/ec2/faqs/)で確認してください。

1. このソースをEC2の専用フォルダーへ配置します。
2. EC2上で`.env`を用意し、ローカルとは別のランダム値を設定します。
3. `APP_HOST`に公開DNS名または公開IP（スキーム・ポートなし）、`BIND_IP=0.0.0.0`、`PORT`に公開ポートを設定します。
4. Security Groupで公開ポートを許可します。PostgreSQLの5432番ポートは公開不要です。
5. EC2上でビルドする場合は`docker compose up -d --build --wait`で起動します。MSI側で作成したARM64イメージを利用する場合は、次の手順を使用します。
6. 公開URLで作成・一覧・詳細・更新・削除を確認し、コンテナ再作成後にも記事が残ることを確認します。

ARM64イメージは作業PCで作成してEC2へ転送できます。EC2側のビルド用メモリやディスクの消費を抑える方法です。

```bash
# 作業PC（WSL）
docker buildx build --platform linux/arm64 --load -t docker-blog-task2:aws .
docker save docker-blog-task2:aws | gzip > docker-blog-image.tar.gz
# ソースと上記ファイルをEC2へ転送後、EC2で実行
gzip -dc docker-blog-image.tar.gz | docker load
docker compose -f docker-compose.yml -f deploy/docker-compose.aws.yml up -d --no-build --wait
```

HTTPで直接公開する構成では`RAILS_FORCE_SSL=false`を使います。HTTPSを終端するリバースプロキシを別途用意した場合は`RAILS_FORCE_SSL=true`に設定します。`APP_HOST`を許可ホストとして登録し、異なるHostヘッダーは拒否します。

教材サイトへの提出時は、このGitHubリポジトリとAWSの公開URLを記入します。

## 依存関係の互換性

Rails 8.1.3を維持するため、JSON gemは3未満に制限しています。JSON 3系ではAPIが変わり、暗号化Cookieの読み取り時にエラーになることを実データ検証で確認したためです。
