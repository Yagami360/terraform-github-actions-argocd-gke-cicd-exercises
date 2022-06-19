# terraform-github-actions-argocd-gke-cicd-exercises
Terraform, GitHub Actions, ArgoCD を使用した GKE 上の Web-API の CI/CD の練習用コード

## ■ 使用法

### ◎ Workload Identity を使用しない場合

[![terrafform workflow for gke](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow.yml/badge.svg)](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow.yml)

Workload Identity を使用しない場合の GitHub Actions のワークフローは、`.github/workflows/terrafform-gke-workflow.yml` に定義している

1. 【初回のみ】GKE 上に Web-API をデプロイする<br>
    GKE クラスター上に Web-API をデプロイしていない場合は、以下のコマンドで GKE クラスタ等をデプロイして、Web-API を使用可能にする。
    既に、デプロイ済みの場合は、以下のコマンドは実行する必要はりません。
    ```sh
    $ sh deploy_api_terraform.sh
    ```

1. 【初回のみ】GitHub Actions 上での GCP の認証設定のための設定を行う<br>
    本 GitHub レポジトリの「Settings」-> 「Secrets」-> 「[Actions](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/settings/secrets/actions)」から、`GCP_SA_KEY` を追加する

    > `GCP_SA_KEY` の値は、`cat .key/${SERVICE_ACCOUNT_NAME}.json | base64` で取得できる

1. ブランチを切る<br>
    `main` ブランチから別ブランチを作成する
    ```sh
    git checkout -b ${BRANCH_NAME}
    ```

1. Web-API のコード or GKE の `*.tf` ファイル or k8s マニフェストを修正する<br>
    `api/` ディレクトリ以下にある Web-API のコードを修正する。又は、GKE に対しての tf ファイル `terraform/gcp/gke/main.tf` を修正する
    又は、`k8s/` ディレクトリ以下にある Web-API の k8s マニフェストを修正する

1. Pull Request を発行する。<br>
    GitHub レポジトリ上で main ブランチに対しての [PR](https://github.com/Yagami360/terraform-github-actions-aws-cicd-exercises/pulls) を出す。

1. PR の内容を `main` ブランチに merge し、GKE 上の Web-API に対しての CI/CD を行う。<br>
    PR の内容に問題なければ、`main` ブランチに merge する。
    merge 処理後、`.github/workflows/terrafform-gke-workflow.yml` で定義したワークフローが実行され 、GKE 上の Web-API に対しての CI/CD が自動的に行われる。

1. [GitHub リポジトリの Actions タブ](https://github.com/Yagami360/terraform-github-actions-aws-cicd-exercises/actions)から、実行されたワークフローのログを確認する
    

1. GKE 上の Web-API に対して、リクエスト処理を行う<br>
    ```sh
    sh resuest_api.sh
    ```

### ◎ Workload Identity を使用する場合

[![terrafform workflow for gke with workload identity](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow_wi.yml/badge.svg)](https://github.com/Yagami360/terraform-github-actions-argocd-gke-cicd-exercises/actions/workflows/terrafform-gke-workflow_wi.yml)

Workload Identity を使用する場合の GitHub Actions のワークフローは、`.github/workflows/terrafform-gke-workflow_wl.yml` に定義している

1. 【初回のみ】GKE 上に Web-API をデプロイする<br>
    GKE クラスター上に Web-API をデプロイしていない場合は、以下のコマンドで GKE クラスタ等を構築して、Web-API を使用可能にする。
    既に、デプロイ済みの場合は、以下のコマンドは実行する必要はりません。
    ```sh
    $ sh deploy_api_terraform.sh
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

1. ブランチを切る<br>
    `main` ブランチから別ブランチを作成する
    ```sh
    git checkout -b ${BRANCH_NAME}
    ```

1. Web-API のコード or GKE の `*.tf` ファイル or k8s マニフェストを修正する<br>
    `api/` ディレクトリ以下にある Web-API のコードを修正する。又は、GKE に対しての tf ファイル `terraform/gcp/gke/main.tf` を修正する
    又は、`k8s/` ディレクトリ以下にある Web-API の k8s マニフェストを修正する

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
