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

# Setup providers
provider "google" {
  project = "ctf-demo-322101"
  region  = "northamerica-northeast2"
  zone    = "northamerica-northeast2-a"
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