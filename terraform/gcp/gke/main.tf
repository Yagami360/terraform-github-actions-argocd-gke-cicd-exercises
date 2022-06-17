#-------------------------------
# プロバイダー設定
#-------------------------------
provider "google" {
  project = "my-project2-303004"
  region  = "us-central1"
}

#-------------------------------
# 各種 GCP サービス有効化
#-------------------------------
resource "google_project_service" "enable_iamcredentials" {
  service = "iamcredentials.googleapis.com"
}

resource "google_project_service" "enable_secretmanager" {
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "enable_cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"
}

#-------------------------------
# GKE 用サービスアカウント（GitHub Actions 用サービスアカウントと同じにする）
#-------------------------------
#resource "google_project_iam_member" "sakai_as_viewer" {
#  role    = "roles/viewer"
#  member  = "user:y034112@gmail.com"
#}

#output service_account_email {
#  value       = module.terraform_github_actions.service_account_email
#  description = "Service Account email address."
#}

#output workload_identity_provider_name {
#  value       = module.terraform_github_actions.workload_identity_provider_name
#  description = "Workload identity provider name, used to authenticate service account."
#}

#-------------------------------
# GCS パケット
#-------------------------------
#data "google_project" "project" {}

# tfstate ファイルを保存する GCS パケット
# terraform apply で作成したインフラ情報は、*.tfstate ファイルに保存され、次回の terraform apply 実行時等で前回のインフラ状態との差分をみる際に利用されるが、
# tfstate ファイルをローカルに置いたままでは複数人で terraform を実行できなくなってしまうので、GCS に保存する
resource "google_storage_bucket" "terraform-tf-states" {
  name          = "terraform-tf-states-bucket"
  location      = "ASIA"
  versioning {
    enabled = true
  }
}

output bucket_name {
  value       = google_storage_bucket.terraform-tf-states.name
  description = "terraform tfstate files"
}

#-------------------------------
# 実行する Terraform 環境情報
#-------------------------------
terraform {
  # バックエンドを GCS にする
  backend "gcs" {
    bucket = "terraform-tf-states-bucket"
    prefix = "terraform/state"
  }

  # プロバイダー情報
  required_providers {
    google = {
      version = "~> 4.13.0"   # Spot VM は、4.13.0 以上で使用可能
    }
  }
}

#-------------------------------
# GKE クラスタ
#-------------------------------
resource "google_container_cluster" "fast_api_cluster" {
  name     = "fast-api-cluster"
  location = "us-central1"

  remove_default_node_pool = true
  initial_node_count       = 1

  network = "default"

  #min_master_version = "1.21.10-gke.2000"
  #node_version       = "1.12.6-gke.7"

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

#-------------------------------
# ノードプール
#-------------------------------
# CPU ノードプール
resource "google_container_node_pool" "fast_api_cpu_pool" {
  name       = "fast-api-cpu-pool"
  location   = "${google_container_cluster.kitemiru_api_terraffrom_cluster.location}"
  cluster    = "${google_container_cluster.kitemiru_api_terraffrom_cluster.name}"
  
  node_count = "1"
  autoscaling {
    min_node_count = 0
    max_node_count = 1
  }

  management {
    auto_repair = true
  }

  node_config {
    machine_type = "n1-standard-4"
    #preemptible  = false    
    #spot = true             # Spot VM

    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
    ]

    metadata {
      disable-legacy-endpoints = "true"
    }
  }
}
