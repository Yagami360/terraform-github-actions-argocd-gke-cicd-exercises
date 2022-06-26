#!/bin/sh
#set -eu
ROOT_DIR=${PWD}
CONTAINER_NAME="terraform-gcp-container"
PROJECT_ID=my-project2-303004
REGION=us-central1
ZONE=us-central1-b
SERVICE_ACCOUNT_NAME=github-actions-sa
CLUSTER_NAME=fast-api-terraform-cluster
API_IMAGE_NAME="fast-api-image-gke"
ARGOCD_APP_NAME="fast-api-terraform-cluster-argocd-app"
#USE_PRIVATE_REPOSITORY=0
USE_PRIVATE_REPOSITORY=1

#-----------------------------
# OS判定
#-----------------------------
if [ "$(uname)" = 'Darwin' ]; then
  OS='Mac'
  echo "Your platform is MacOS."  
elif [ "$(expr substr $(uname -s) 1 5)" = 'Linux' ]; then
  OS='Linux'
  echo "Your platform is Linux."  
elif [ "$(expr substr $(uname -s) 1 10)" = 'MINGW32_NT' ]; then                                                                                           
  OS='Cygwin'
  echo "Your platform is Cygwin."  
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

#-----------------------------
# gcloud コマンドをインストールする
#-----------------------------
gcloud -v &> /dev/null
if [ $? -ne 0 ] ; then
    if [ ${OS} = "Mac" ] ; then
        # Cloud SDKのパッケージをダウンロード
        cd ${HOME}
        curl -OL https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-308.0.0-darwin-x86_64.tar.gz
        tar -zxvf google-cloud-sdk-308.0.0-darwin-x86_64.tar.gz
        rm -rf google-cloud-sdk-308.0.0-darwin-x86_64.tar.gz

        # Cloud SDKのパスを通す
        ./google-cloud-sdk/install.sh
        source ~/.zshrc

        # Cloud SDK の初期化
        gcloud init
        cd ${ROOT_DIR}
    fi
fi
echo "gcloud version : `gcloud -v`"

# デフォルト値の設定
#sudo gcloud components update
gcloud config set project ${PROJECT_ID}
gcloud config set compute/region ${REGION}
gcloud config list

#-----------------------------
# kubectl コマンドをインストールする
#-----------------------------
kubectl version --client &> /dev/null
if [ $? -ne 0 ] ; then
    if [ ${OS} = "Mac" ] ; then
        # 最新版取得
        curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/darwin/amd64/kubectl

        # Ver指定(ex:1.40)
        curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.14.0/bin/darwin/amd64/kubectl

        # アクセス権限付与
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
    elif [ ${OS} = "Linux" ] ; then
        curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"        
        chmod +x ./kubectl
        sudo mv ./kubectl /usr/local/bin/kubectl
    fi
fi

echo "kubectl version : `kubectl version`"

#-----------------------------
# ArgoCD CLI のインストール
#-----------------------------
argocd version --client &> /dev/null
if [ $? -ne 0 ] ; then
    if [ ${OS} = "Mac" ] ; then
        brew install argocd
    elif [ ${OS} = "Linux" ] ; then
        curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /usr/local/bin/argocd
    fi
fi

echo "argocd version : `argocd version`"

#-----------------------------
# terraform コンテナ起動
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

#-----------------------------
# GCS パケットを作成する
#-----------------------------
# terraform を初期化する。
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gcs && terraform init"

# 作成したテンプレートファイルの定義内容を確認する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gcs && terraform plan"

# 定義を適用してインスタンスを作成する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gcs && terraform apply -auto-approve"

# terraform が作成したオブジェクトの内容を確認
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gcs && terraform show"

#-----------------------------
# GitHub Actions 用サービスアカウントを作成する
#-----------------------------
# terraform を初期化する。
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform init"

# 作成したテンプレートファイルの定義内容を確認する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform plan"

# 定義を適用してインスタンスを作成する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform apply -auto-approve"

# terraform が作成したオブジェクトの内容を確認
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/iam && terraform show"

# サービスアカウントの秘密鍵 (json) を生成する
if [ ! -e "${ROOT_DIR}/.key/${SERVICE_ACCOUNT_NAME}.json" ] ; then
    rm -f ${ROOT_DIR}/.key/${SERVICE_ACCOUNT_NAME}.json
    mkdir -p ${ROOT_DIR}/.key
    gcloud iam service-accounts keys create ${ROOT_DIR}/.key/${SERVICE_ACCOUNT_NAME}.json --iam-account=${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com
    echo "GCP_SA_KEY : `cat ${ROOT_DIR}/.key/${SERVICE_ACCOUNT_NAME}.json | base64`"
fi

#-----------------------------
# docker image を GCR に push
#-----------------------------
bash -c 'docker pull gcr.io/${PROJECT_ID}/${API_IMAGE_NAME}:latest || exit 0'
docker build -t gcr.io/${PROJECT_ID}/${API_IMAGE_NAME}:latest --cache-from gcr.io/${PROJECT_ID}/${API_IMAGE_NAME}:latest -f api/Dockerfile .
docker push gcr.io/${PROJECT_ID}/${API_IMAGE_NAME}:latest

#-----------------------------
# GKE クラスタとノードプールを作成する
#-----------------------------
# terraform を初期化する。
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform init"

# 作成したテンプレートファイルの定義内容を確認する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform plan"

# 定義を適用してインスタンスを作成する
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform apply -auto-approve"

# terraform が作成したオブジェクトの内容を確認
docker exec -it ${CONTAINER_NAME} /bin/sh -c "cd gcp/gke && terraform show"

#-----------------------------
# 各種 k8s リソースをデプロイする
#-----------------------------
# 作成したクラスタに切り替える
gcloud container clusters get-credentials ${CLUSTER_NAME} --project ${PROJECT_ID} --region ${ZONE}

# API の k8s リソースのデプロイ
kubectl apply -f k8s/fast_api.yml

# ArgoCD の k8s リソースのデプロイ
kubectl create namespace argocd || kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
sleep 30

#-----------------------------
# ArgoCD API Server にログインする
#-----------------------------
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 120
ARGOCD_SERVER_DOMAIN=`kubectl describe service argocd-server --namespace argocd | grep "LoadBalancer Ingress" | awk '{print $3}'`
echo "ARGOCD_SERVER_DOMAIN : ${ARGOCD_SERVER_DOMAIN}"

# パスワード確認
ARGOCD_PASSWARD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
echo "ArgoCD passward : ${ARGOCD_PASSWARD}"

# ログイン
argocd login ${ARGOCD_SERVER_DOMAIN} --username admin --password ${ARGOCD_PASSWARD}

#-----------------------------
# ArgoCD で管理したい k8s マニフェストファイルと Git リポジトリーの同期を行う
#-----------------------------
# ArgoCD で管理するクラスターを選択し設定する
K8S_CLUSTER_NAME=gke_${PROJECT_ID}_${ZONE}_${CLUSTER_NAME}
#K8S_CLUSTER_NAME=`argocd cluster add | grep ${CLUSTER_NAME} | awk '{print $2}'`
argocd cluster add -y ${K8S_CLUSTER_NAME}

# ArgoCD にプライベートレポジトリを追加
#if [ ! ${USE_PRIVATE_REPOSITORY} = 0 ] ; then
#    argocd repo add "git@github.com:Yagami360/terraform-github-actions-argocd-gke-cicd-exercises.git" --ssh-private-key-path "${HOME}/.ssh/id_rsa" --insecure-skip-server-verification
#fi

# ArgoCD で管理する GitHub の k8s マニフェストファイルのフォルダーを設定
if [ ! ${USE_PRIVATE_REPOSITORY} = 0 ] ; then
    kubectl apply -f k8s/argocd-app-private.yml
else
    kubectl apply -f k8s/argocd-app.yml

# ArgoCD と GitHub レポジトリの同期を行う
argocd app sync ${ARGOCD_APP_NAME}

#-----------------------------
# ArgoCD API Server にアクセスする
#-----------------------------
if [ ${OS} = "Mac" ] ; then
    open "https://${ARGOCD_SERVER_DOMAIN}" &
fi
