#-------------------------------
# プロバイダー設定
#-------------------------------
provider "google" {
  project = "my-project2-303004"
  region  = "us-central1"
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
# GCR
#-------------------------------
resource "google_container_registry" "fast-api-image-gke-repo" {
}
