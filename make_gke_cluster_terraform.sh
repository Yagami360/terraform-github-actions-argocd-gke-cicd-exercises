#!/bin/sh
#set -eu
ROOT_DIR=${PWD}
PROJECT_ID=my-project2-303004
CONTAINER_NAME="terraform-gcp-container"

#-----------------------------
# terraform
#-----------------------------
cd terraform

# terraform コンテナ起動
docker-compose -f docker-compose.yml stop
docker-compose -f docker-compose.yml up -d

# デフォルトのサービスアカウント（~.config/gcloud/application_default_credentials.json）でログイン
#docker exec -it ${CONTAINER_NAME} /bin/sh -c "gcloud auth application-default login"
#docker exec -it ${CONTAINER_NAME} /bin/sh -c "cat /.config/gcloud/application_default_credentials.json"
#docker exec -it ${CONTAINER_NAME} /bin/sh -c "gcloud config list"

# GCP プロジェクト設定
docker exec -it ${CONTAINER_NAME} /bin/sh -c "gcloud config set project ${PROJECT_ID}"

# terraform を初期化する。
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform init"

# 作成したテンプレートファイルの定義内容を確認する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform plan"

# 定義を適用してインスタンスを作成する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform apply"

# terraform が作成したオブジェクトの内容を確認
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform show"
