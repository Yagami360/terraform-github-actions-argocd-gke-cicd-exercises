#!/bin/sh
set -eu
PROJECT_ID=my-project2-303004
ZONE=us-central1-b
CLUSTER_NAME=fast-api-terraform-cluster
ARGOCD_APP_NAME="fast-api-terraform-cluster-argocd-app"

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
# ArgoCD CLI のインストール
#-----------------------------
if [ ${OS} = "Mac" ] ; then
    brew install argocd
elif [ ${OS} = "Linux" ] ; then
    curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x /usr/local/bin/argocd
fi

echo "argocd version : `argocd version`"

#-----------------------------
# ArgoCD API Server にログインする
#-----------------------------
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
sleep 30
ARGOCD_SERVER_DOMAIN=`kubectl describe service argocd-server --namespace argocd | grep "LoadBalancer Ingress" | awk '{print $3}'`
echo "ARGOCD_SERVER_DOMAIN : ${ARGOCD_SERVER_DOMAIN}"

# パスワード確認
ARGOCD_PASSWARD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
echo "ArgoCD passward : ${ARGOCD_PASSWARD}"

# ログイン
argocd login ${ARGOCD_SERVER_DOMAIN} --username admin --password ${ARGOCD_PASSWARD}

#-----------------------------
# ArgoCD API Server にアクセスする
#-----------------------------
if [ ${OS} = "Mac" ] ; then
    open "https://${ARGOCD_SERVER_DOMAIN}" &
fi

#-----------------------------
# ArgoCD で管理したい k8s マニフェストファイルと Git リポジトリーの同期を行う
#-----------------------------
# ArgoCD で管理するクラスターを選択し設定する
K8S_CLUSTER_NAME=gke_${PROJECT_ID}_${ZONE}_${CLUSTER_NAME}
#K8S_CLUSTER_NAME=`argocd cluster add | grep ${CLUSTER_NAME} | awk '{print $2}'`
argocd cluster add ${K8S_CLUSTER_NAME}

# ArgoCD で管理する GitHub の k8s マニフェストファイルのフォルダーを設定
kubectl apply -f k8s/argocd-app.yml

# ArgoCD と GitHub レポジトリの同期を行う
argocd app sync ${ARGOCD_APP_NAME}
