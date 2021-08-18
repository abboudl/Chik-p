terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.80.0"
    }
  }
}

provider "google" {
  project = var.google_project
  region = var.google_region
  zone = var.google_zone
}

resource "google_project_service" "api" {
  count = length(var.api)
  service = var.api[count.index]

  disable_dependent_services = true
  disable_on_destroy = false
}

data "google_client_config" "provider" {
  depends_on = [google_project_service.api]
}