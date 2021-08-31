/*
resource "helm_release" "wireguard" {
  name             = "wireguard-vpn"
  repository       = "https://k8s-at-home.com/charts/"
  chart            = "wireguard"
  namespace        = "wireguard"
  create_namespace = true
  depends_on       = [google_container_node_pool.kube_node_pool]
}
*/