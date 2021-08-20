terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "3.80.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "2.25.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.4.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.2.0"
    }
  }
}

# Initialize APIs
module "initialize" {
  source = "./modules/initialize"

  google_project = var.google_project
  google_region  = var.google_region
  google_zone    = var.google_zone
}

# Setup providers
provider "google" {
  project = module.initialize.project
  region  = module.initialize.client_config.region
  zone    = module.initialize.client_config.zone
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host  = "https://${google_container_cluster.kube_cluster.endpoint}"
  token = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(
    google_container_cluster.kube_cluster.master_auth[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host  = "https://${google_container_cluster.kube_cluster.endpoint}"
    token = data.google_client_config.provider.access_token
    cluster_ca_certificate = base64decode(
      google_container_cluster.kube_cluster.master_auth[0].cluster_ca_certificate
    )
  }
}