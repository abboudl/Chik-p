terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.79.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "2.25.0"
    }
  }
}

provider "google" {
  project = "terraform-322603"
  region  = "northamerica-northeast1"
  zone    = "northamerica-northeast1-a"
}
