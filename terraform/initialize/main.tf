terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.80.0"
    }
  }
}

data "google_billing_account" "acct" {
  display_name = "My Billing Account"
}

# Create the project
resource "random_pet" "prefix" {}

resource "random_id" "id" {
  prefix      = "${random_pet.prefix.id}-"
  byte_length = 3
}

resource "google_project" "ctf" {
  name                = var.google_project
  project_id          = random_id.id.hex
  billing_account     = data.google_billing_account.acct.id
  auto_create_network = false
  skip_delete         = false

  provisioner "local-exec" {
    when    = destroy
    command = "gcloud beta billing projects unlink ${self.project_id}"
  }
}

provider "google" {
  region = var.google_region
  zone   = var.google_zone
}

resource "google_project_service" "api" {
  count = length(var.api)

  project                    = google_project.ctf.id
  service                    = var.api[count.index]
  disable_dependent_services = true
  disable_on_destroy         = false
}

data "google_client_config" "provider" {
  depends_on = [google_project_service.api]
}