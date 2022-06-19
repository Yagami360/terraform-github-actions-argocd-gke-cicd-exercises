# terraform-github-actions-argocd-gke-cicd-exercises
GitHub Actions, Terraform, ArgoCD を使用してた GKE 上の Web-API の CI/CD の練習用コード

## ■ 使用法

### ◎ Workload Identity を使用しない場合

[![terrafform workflow for gke](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow.yml/badge.svg)](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow.yml)

Workload Identity を使用しない場合の GitHub Actions のワークフローは、`.github/workflows/terrafform-gke-workflow.yml` に定義している

1. 【初回のみ】`*.tfstate` ファイルを保管するための GCS パケットを作成する<br>
    `terraform apply` を実行すると、tf ファイルに基づいて、各種インフラが作成されるが、そのインフラ情報が、`*.tfstate` ファイルに自動的に保存され（場所は、tf ファイルと同じディレクトリ内）、次回の `terraform apply` 実行時等で前回のインフラ状態との差分をみる際に利用されるが、tfstate ファイルをローカルに保存すると、複数人で terraform を実行できなくなってしまう。この問題を解決するためには、tfstate ファイルを GCS 上に保管するようにする

    > 尚、`*.tfstate` ファイルを保管するための GCS パケットを terraform を使用して作成する場合も、GCS パケット上に tfstate ファイルを保存しようとしても、そもそも最初の段階では GCS パケットが存在しなくて保存できないので、`*.tfstate` ファイルをローカルに保存するようにする

    ```sh
    sh make_gcs_bucket_terraform.sh
    ```

1. 【初回のみ】GitHub Actions 用サービスアカウントの作成する<br>

    - gcloud コマンドを使用して作成する場合
        ```sh
        sh make_service_account.sh
        ```

    - terraform を使用して作成する場合
        ```sh
        sh make_service_account_terraform.sh
        ```

1. 【初回のみ】GitHub Actions 上での GCP の認証設定のための設定を行う<br>
    本 GitHub レポジトリの「Settings」-> 「Secrets」-> 「[Actions](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/settings/secrets/actions)」から、`GCP_SA_KEY` を追加する

    > `GCP_SA_KEY` の値は、`cat .key/${SERVICE_ACCOUNT_NAME}.json | base64` で取得できる

1. ブランチを切る<br>
    `main` ブランチから別ブランチを作成する
    ```sh
    git checkout -b ${BRANCH_NAME}
    ```

1. Web-API のコードか GKE の `*.tf` ファイルを修正する<br>
    `api/` ディレクトリ以下にある Web-API のコードを修正する。又は、GKE に対しての tf ファイル `terraform/gcp/gke/main.tf` を修正する

1. Pull Request を発行する。<br>
    GitHub レポジトリ上で main ブランチに対しての [PR](https://github.com/Yagami360/terraform-github-actions-aws-cicd-exercises/pulls) を出す。

1. PR の内容を `main` ブランチに merge し、GKE 上の Web-API に対しての CI/CD を行う。<br>
    PR の内容に問題なければ、`main` ブランチに merge する。
    merge 処理後、`.github/workflows/terrafform-gke-workflow.yml` で定義したワークフローが実行され 、GKE 上の Web-API に対しての CI/CD が自動的に行われる。

1. [GitHub リポジトリの Actions タブ](https://github.com/Yagami360/terraform-github-actions-aws-cicd-exercises/actions)から、実行されたワークフローのログを確認する
    
1. 【初回のみ】ArgoCD の設定<br>
    GKE クラスタの作成と ArgoCD k8s リソースのデプロイが正常に行えた後に、

    1. ArgoCD CLI をインストールする<br>
        - MacOS の場合<br>    
            ```sh
            brew install argocd
            ```

        - Linux の場合<br>
            ```sh
            curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
            chmod +x /usr/local/bin/argocd
            ```

    1. ArgoCD API Server にログインする<br>
        ```sh
        kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
        sleep 30
        ARGOCD_SERVER_DOMAIN=`kubectl describe service argocd-server --namespace argocd | grep "LoadBalancer Ingress" | awk '{print $3}'`
        echo "ARGOCD_SERVER_DOMAIN : ${ARGOCD_SERVER_DOMAIN}"

        # パスワード確認
        ARGOCD_PASSWARD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
        echo "ArgoCD passward : ${ARGOCD_PASSWARD}"

        # ログイン
        argocd login ${ARGOCD_SERVER_DOMAIN} --username admin --password ${ARGOCD_PASSWARD}
        ```

    1. ArgoCD API Server にアクセスする<br>
        ```sh
        open "https://${ARGOCD_SERVER_DOMAIN}"
        ```
        - Username : `admin`
        - Password : 以下のコマンドで取得可能
            ```sh
            ARGOCD_PASSWARD=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
            echo "ArgoCD passward : ${ARGOCD_PASSWARD}"
            ```

    1. ArgoCD で管理する GKE クラスターを選択し設定する<br>
        ```sh
        K8S_CLUSTER_NAME=gke_${PROJECT_ID}_${ZONE}_${CLUSTER_NAME}
        argocd cluster add ${K8S_CLUSTER_NAME}
        ```

    1. ArgoCD で管理する GitHub の k8s マニフェストファイルのフォルダーを設定する<br>
        ```sh
        kubectl apply -f k8s/argocd-app.yml
        ```

    1. ArgoCD と GitHub レポジトリの同期を行う<br>
        ```sh
        argocd app sync ${ARGOCD_APP_NAME}
        ```

1. GKE 上の Web-API に対して、リクエスト処理を行う<br>
    ```sh
    sh resuest_api.sh
    ```

### ◎ Workload Identity を使用する場合

[![terrafform workflow for gke with workload identity](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow_wi.yml/badge.svg)](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow_wi.yml)

Workload Identity を使用する場合の GitHub Actions のワークフローは、`.github/workflows/terrafform-gke-workflow_wl.yml` に定義している

1. 【初回のみ】`*.tfstate` ファイルを保管するための GCS パケットを作成する<br>
    `terraform apply` を実行すると、tf ファイルに基づいて、各種インフラが作成されるが、そのインフラ情報が、`*.tfstate` ファイルに自動的に保存され（場所は、tf ファイルと同じディレクトリ内）、次回の `terraform apply` 実行時等で前回のインフラ状態との差分をみる際に利用されるが、tfstate ファイルをローカルに保存すると、複数人で terraform を実行できなくなってしまう。この問題を解決するためには、tfstate ファイルを GCS 上に保管するようにする

    > 尚、`*.tfstate` ファイルを保管するための GCS パケットを terraform を使用して作成する場合も、GCS パケット上に tfstate ファイルを保存しようとしても、そもそも最初の段階では GCS パケットが存在しなくて保存できないので、`*.tfstate` ファイルをローカルに保存するようにする

    ```sh
    sh make_gcs_bucket_terraform.sh
    ```

1. 【初回のみ】GitHub Actions 用サービスアカウントの作成し、Workload Identity と連携する<br>

    - gcloud コマンドを使用して作成する場合
        ```sh
        sh make_service_account.sh
        ```

    - terraform を使用して作成する場合
        ```sh
        sh make_service_account_terraform.sh
        ```

1. 【初回のみ】GitHub Actions 上での GCP の認証設定のための設定を行う<br>
    `.github/workflows/terrafform-gke-workflow_wi.yml` の環境変数 `env.SERVICE_ACCOUNT` と `env.WORKLOAD_IDENTITY_PROVIDER` に、それぞれ作成したサービスアカウントと workload identity プロバイダーの名前を設定する。
    
    > サービスアカウントの名前は、`terraform/gcp/iam/main.tf` の `google_service_account.github_actions_service_account.account_id` から取得できる

    > workload identity プロバイダーの名前は、以下のコマンドで取得できる
    > ```sh
    > gcloud iam workload-identity-pools providers describe ${WORKLOAD_IDENTITY_PROVIDER_NAME} \
    >     --project="${PROJECT_ID}" \
    >     --location="global" \
    >     --workload-identity-pool=${WORKLOAD_IDENTITY_POOL_NAME} \
    >     --format='value(name)'
    > ```

1. 【初回のみ】ArgoCD CLI をインストールする<br>
    - MacOS の場合<br>    
        ```sh
        brew install argocd
        ```

    - Linux の場合<br>
        ```sh
        curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /usr/local/bin/argocd
        ```

1. ブランチを切る<br>
    `main` ブランチから別ブランチを作成する
    ```sh
    git checkout -b ${BRANCH_NAME}
    ```

1. Web-API のコードか GKE の *.tf ファイルを修正する<br>
    `api` ディレクトリ以下にある Web-API のコードを修正する。又は、GKE に対しての tf ファイル `terraform/gcp/gke/main.tf` を修正する

1. Pull Request を発行する。<br>
    GitHub レポジトリ上で main ブランチに対しての [PR](https://github.com/Yagami360/terraform-github-actions-aws-cicd-exercises/pulls) を出す。

1. PR の内容を `main` ブランチに merge し、GKE 上の Web-API に対しての CI/CD を行う。<br>
    PR の内容に問題なければ、`main` ブランチに merge する。
    merge 処理後、`.github/workflows/terrafform-gke-workflow_wl.yml` で定義したワークフローが実行され 、GKE 上の Web-API に対しての CI/CD が自動的に行われる。

1. [GitHub リポジトリの Actions タブ](https://github.com/Yagami360/terraform-github-actions-aws-cicd-exercises/actions)から、実行されたワークフローのログを確認する

1. GKE 上の Web-API に対して、リクエスト処理を行う<br>
    ```sh
    sh resuest_api.sh
    ```
