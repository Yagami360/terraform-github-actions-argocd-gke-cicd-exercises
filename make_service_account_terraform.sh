#!/bin/sh
#set -eu
ROOT_DIR=${PWD}
CONTAINER_NAME="terraform-gcp-container"

#-----------------------------
# terraform
#-----------------------------
# terraform コンテナ起動
docker-compose -f docker-compose.yml stop
docker-compose -f docker-compose.yml up -d

# terraform を初期化する。
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam/github_actions && terraform init"

# 作成したテンプレートファイルの定義内容を確認する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam/github_actions && terraform plan"

# 定義を適用してインスタンスを作成する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam/github_actions && terraform apply"

# terraform が作成したオブジェクトの内容を確認
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam/github_actions && terraform show"
