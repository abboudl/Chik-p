terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.79.0"
    }
  }
}

provider "google" {
  project = "terraform-322603"
  region  = "northamerica-northeast1"
  zone    = "northamerica-northeast1-a"
}