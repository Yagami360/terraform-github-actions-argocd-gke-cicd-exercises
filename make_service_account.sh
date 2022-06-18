#!/bin/sh
#set -eu
ROOT_DIR=${PWD}
PROJECT_ID=my-project2-303004
SERVICE_ACCOUNT_NAME=github-actions-service-account
WORKLOAD_IDENTITY_POOL_NAME=github-actions-pool
WORKLOAD_IDENTITY_PROVIDER_NAME=github-actions-provider
GITHUB_REPOSITORY_NAME=terraform-github-actions-argocd-gke-cicd-exercises

# サービスアカウント作成権限のある個人アカウントに変更
gcloud auth login
gcloud config set project ${PROJECT_ID}

# GKE 上のコンテナ内で kubectl コマンドの 　Pod を認識させるためのサービスアカウントを作成する
if [ "$(gcloud iam service-accounts list | grep ${SERVICE_ACCOUNT_NAME})" ] ; then
    gcloud iam service-accounts delete ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
fi
gcloud iam service-accounts create ${SERVICE_ACCOUNT_NAME}

# サービスアカウントに必要な権限を付与する
#gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/owner"
gcloud projects add-iam-policy-binding ${PROJECT_ID} --member="serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" --role="roles/iam.serviceAccountUser" 

# サービスアカウントの秘密鍵 (json) を生成する
rm -rf .key
mkdir -p ${ROOT_DIR}/.key
gcloud iam service-accounts keys create ${ROOT_DIR}/.key/${SERVICE_ACCOUNT_NAME}.json --iam-account=${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com

# 作成した json 鍵を環境変数に反映
#export GOOGLE_APPLICATION_CREDENTIALS="ROOTDIR/key/{SERVICE_ACCOUNT_NAME}.json"
#gcloud auth activate-service-account SERVICEACCOUNTNAME@{PROJECT_ID}.iam.gserviceaccount.com --key-file ROOTDIR/key/{SERVICE_ACCOUNT_NAME}.json
#gcloud auth list

# サービスアカウントの一時的な認証情報を作成できるようにするために、IAM Service Account Credentials APIを有効化
gcloud services enable iamcredentials.googleapis.com --project ${PROJECT_ID}

# Workload Identity プール（Workload Identityプールは外部IDとGoogle Cloudとの紐付けを設定したWorkload Identityプロバイダをグループ化し、管理するためのもの）を作成
if [ "$(gcloud iam workload-identity-pools list --location global | grep ${WORKLOAD_IDENTITY_POOL_NAME})" ] ; then
    gcloud iam workload-identity-pools delete ${WORKLOAD_IDENTITY_POOL_NAME}
fi
gcloud iam workload-identity-pools create ${WORKLOAD_IDENTITY_POOL_NAME} --project="${PROJECT_ID}" --location="global"
export WORKLOAD_IDENTITY_POOL_ID=$( gcloud iam workload-identity-pools describe "${WORKLOAD_IDENTITY_POOL_NAME}" --project="${PROJECT_ID}" --location="global" --format="value(name)" )
echo "WORKLOAD_IDENTITY_POOL_ID : ${WORKLOAD_IDENTITY_POOL_ID}"

# Workload Identity プールの中に Workload Identity プロバイダーを作成。Workload Identity プロバイダーと GitHub Actions のワークフローで指定する必要がある
if [ "$(gcloud iam workload-identity-pools providers list --workload-identity-pool ${WORKLOAD_IDENTITY_POOL_NAME} --location global | grep ${WORKLOAD_IDENTITY_PROVIDER_NAME})" ] ; then
    gcloud iam workload-identity-pools providers delete ${WORKLOAD_IDENTITY_PROVIDER_NAME} --workload-identity-pool=${WORKLOAD_IDENTITY_POOL_NAME} --location="global"
fi
gcloud iam workload-identity-pools providers create-oidc ${WORKLOAD_IDENTITY_PROVIDER_NAME} \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool=${WORKLOAD_IDENTITY_POOL_NAME} \
    --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
    --issuer-uri="https://token.actions.githubusercontent.com"

# Workload Identity と GitHub Actions 用サービスアカウントの連携
gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --project="${PROJECT_ID}" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${GITHUB_REPOSITORY_NAME}"

# Workload Identity プロバイダの名前（projects/${PROJECT_ID}/locations/global/workloadIdentityPools/${POOL_NAME}/providers/${PROVIDER_NAME} の形式）を取得
gcloud iam workload-identity-pools providers describe ${WORKLOAD_IDENTITY_PROVIDER_NAME} \
    --project="${PROJECT_ID}" \
    --location="global" \
    --workload-identity-pool=${WORKLOAD_IDENTITY_POOL_NAME} \
    --format='value(name)'
