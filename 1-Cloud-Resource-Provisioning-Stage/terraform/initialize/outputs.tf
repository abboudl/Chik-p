output "client_config" {
  value     = data.google_client_config.provider
  sensitive = true
}

output "project" {
  value = google_project.ctf.project_id
}
