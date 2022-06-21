#-------------------------------
# プロバイダー設定
#-------------------------------
provider "google" {
  project = "my-project2-303004"
  region  = "us-central1"
  zone    = "us-central1-c"
}

provider "google-beta" {
  project = "my-project2-303004"
  region  = "us-central1"
  zone    = "us-central1-c"
}

#-------------------------------
# 実行する Terraform 環境情報
#-------------------------------
terraform {
  # バックエンドを GCS にする
  backend "gcs" {
    bucket = "terraform-tf-states-bucket"
    prefix = "gcp/iam"
  }

  # プロバイダー情報
#  required_providers {
#    google = {
#      version = "~> 4.13.0"
#    }
#  }
}

#-------------------------------
# サービスアカウント
#-------------------------------
# ローカル変数
locals {
  repository_owner = "Yagami360"
  repository_name = "terraform-github-actions-argocd-gke-cicd-exercises"
}

# GitHub Actions 用のサービスアカウント
resource "google_service_account" "github_actions_service_account" {
  project      = "my-project2-303004"
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions of Terraform"
}

# GitHub Actions 用のサービスアカウントの IAM 権限設定（サービスアカウントに必要な権限を付与する）
resource "google_project_iam_member" "github_actions_iam" {
  project = "my-project2-303004"
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.github_actions_service_account.email}"
}

# Workload Identity プール（外部IDとGoogle Cloudとの紐付けを設定した Workload Identity プロバイダをグループ化し、管理するためのもの）
resource "google_iam_workload_identity_pool" "github_actions_workload_identity_pool" {
  provider                  = google-beta
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "Terraform GitHub Actions"
  description               = "Used by GitHub Actions"
}

# Workload Identity プロバイダー（GitHub Actionsのワークフローで利用するために必要）
resource "google_iam_workload_identity_pool_provider" "github_actions_workload_identity_provider" {
  provider                           = google-beta
  workload_identity_pool_id          = google_iam_workload_identity_pool.github_actions_workload_identity_pool.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  attribute_mapping                  = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.aud"        = "assertion.aud"
    "attribute.repository" = "assertion.repository"
  }

  oidc {
    allowed_audiences = []
    issuer_uri        = "https://token.actions.githubusercontent.com"
  }
}

# WorklWorkload Identity と GitHub Actions 用サービスアカウントの連携
resource "google_service_account_iam_member" "bind_sa_to_repo" {
  service_account_id = google_service_account.github_actions_service_account.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github_actions_workload_identity_pool.name}/attribute.repository/${local.repository_owner}/${local.repository_name}"
}
