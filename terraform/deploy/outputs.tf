output "gke_kubectl_setup" {
  value = "gcloud container clusters get-credentials hosted-challenges-cluster --region northamerica-northeast2-a"
}