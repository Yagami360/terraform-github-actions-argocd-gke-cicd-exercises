# terraform-github-actions-argocd-gke-cicd-exercises
GitHub Actions, Terraform, ArgoCD を使用してた GKE 上の Web-API の CI/CD の練習用コード

## ■ 使用法

### ◎ Workload Identity を使用しない場合

Workload Identity を使用しない場合の GitHub Actions のワークフローは、`.github/workflows/terrafform-gke-workflow.yml` に定義している

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

1. 【初回のみ】`*.tfstate` ファイルを保管するための GCS パケットを作成する<br>

    - gcloud コマンドを使用して作成する場合
        ```sh
        sh make_gcs_bucket.sh
        ```

    - terraform を使用して作成する場合
        ```sh
        sh make_gcs_bucket_terraform.sh
        ```

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

### ◎ Workload Identity を使用する場合

Workload Identity を使用する場合の GitHub Actions のワークフローは、`.github/workflows/terrafform-gke-workflow_wl.yml` に定義している

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

1. 【初回のみ】`*.tfstate` ファイルを保管するための GCS パケットを作成する<br>

    - gcloud コマンドを使用して作成する場合
        ```sh
        sh make_gcs_bucket.sh
        ```

    - terraform を使用して作成する場合
        ```sh
        sh make_gcs_bucket_terraform.sh
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
