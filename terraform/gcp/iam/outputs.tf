output service_account_email {
  value       = google_service_account.github_actions_service_account.email
  description = "Email address of GitHub actions service account."
}

output workload_identity_provider_name {
  value       = google_iam_workload_identity_pool_provider.github_actions_workload_identity_provider.name
  description = "Workload identity provider name, used to authenticate service account."
}