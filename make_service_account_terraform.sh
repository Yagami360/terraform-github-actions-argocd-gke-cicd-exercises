#!/bin/sh
#set -eu
ROOT_DIR=${PWD}
PROJECT_ID=my-project2-303004
CONTAINER_NAME="terraform-gcp-container"
SERVICE_ACCOUNT_NAME=github-actions-sa

#-----------------------------
# terraform
#-----------------------------
cd terraform

# terraform コンテナ起動
docker-compose -f docker-compose.yml stop
docker-compose -f docker-compose.yml up -d

# デフォルトのサービスアカウント（~.config/gcloud/application_default_credentials.json）でログイン
#docker exec -it ${CONTAINER_NAME} /bin/sh -c "gcloud auth application-default login"
#docker exec -it ${CONTAINER_NAME} /bin/sh -c "gcloud config list"

# GCP プロジェクト設定
docker exec -it ${CONTAINER_NAME} /bin/sh -c "gcloud config set project ${PROJECT_ID}"

# terraform を初期化する。
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform init"

# 作成したテンプレートファイルの定義内容を確認する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform plan"

# 定義を適用してインスタンスを作成する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform apply"

# terraform が作成したオブジェクトの内容を確認
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform show"

#-----------------------------
# サービスアカウントの秘密鍵 (json) を生成する
#-----------------------------
rm -rf .key
mkdir -p .key
gcloud iam service-accounts keys create .key/${SERVICE_ACCOUNT_NAME}.json --iam-account=${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
echo "GCP_SA_KEY : `cat .key/${SERVICE_ACCOUNT_NAME}.json | base64`"