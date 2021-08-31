# HAProxy Host Internal IP
locals {
  haproxy_internal_ip = "10.10.10.9"
}

resource "google_compute_address" "haproxy_internal_ip" {
  name         = "haproxy-internal-static-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.dmz_subnet.id
  address      = local.haproxy_internal_ip
}

# HAProxy Host Static External Public IP
resource "google_compute_address" "haproxy_external_ip" {
  name         = "haproxy-external-static-ip"
  address_type = "EXTERNAL"
  network_tier = var.network_tier
}

# Get HAProxy Public IP
data "google_compute_address" "haproxy_public_ip" {
  name = google_compute_address.haproxy_external_ip.name
}

# Create HAProxy A Record
resource "google_dns_record_set" "haproxy_dns" {
  managed_zone = google_dns_managed_zone.dns_zone.name
  name         = "haproxy.${var.internal_dns_zone_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [local.haproxy_internal_ip]
}

# Create HAProxy Host
resource "google_compute_instance" "haproxy_instance" {
  name         = "haproxy-int-ctf"
  description  = "VM instance will host ISSessionsCTF HAProxy container acting as a proxy to TCP-Based Hosted Challenges."
  hostname     = "haproxy.${var.internal_dns_zone_domain}"
  machine_type = "e2-highcpu-2"
  tags         = ["haproxy-server"]

  boot_disk {
    device_name = "haproxy"

    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-focal-v20210720"
      size  = 20
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz_subnet.id
    network_ip = local.haproxy_internal_ip

    access_config {
      network_tier = var.network_tier
      nat_ip       = data.google_compute_address.haproxy_public_ip.address
    }
  }

  shielded_instance_config {
    enable_vtpm                 = true
    enable_integrity_monitoring = true
    enable_secure_boot          = true
  }

  reservation_affinity {
    type = "ANY_RESERVATION"
  }

  scheduling {
    on_host_maintenance = "MIGRATE"
  }

  metadata = {
    ssh-keys = file(var.ansible_public_key_path)
  }
}

# Create Kubernetes Cluster
resource "google_container_cluster" "kube_cluster" {
  name                     = "hosted-challenges-cluster"
  initial_node_count       = 1
  remove_default_node_pool = true
  network                  = google_compute_network.vpc_network.id
  subnetwork               = google_compute_subnetwork.internal_hosted_challenges_subnet.id
  enable_shielded_nodes    = true

  ip_allocation_policy {}

  release_channel {
    channel = "STABLE"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "10.10.100.0/28"

    master_global_access_config {
      enabled = true
    }
  }

  network_policy {
    enabled = true
  }
}

locals {
  cluster_node_num = 3
}

resource "google_container_node_pool" "kube_node_pool" {
  name              = "hosted-challenges-pool"
  cluster           = google_container_cluster.kube_cluster.id
  node_count        = local.cluster_node_num
  max_pods_per_node = 110

  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = 50
    image_type   = "cos_containerd"
    machine_type = "e2-highmem-2"
    tags         = ["hosted-challenges-node"]
    metadata = {
      disable-legacy-endpoints = true
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }
}

# Allow HTTP Access to HAProxy Stats Panel
resource "google_compute_firewall" "haproxy_stats_panel" {
  name          = "allow-http-to-haproxy-stats-panel"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = "1000"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["haproxy-server"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

# Get list of nodes in kubernetes cluster
data "google_compute_instance_group" "kube" {
  self_link = google_container_node_pool.kube_node_pool.instance_group_urls[0]
}

locals {
  kube_nodes = tolist(data.google_compute_instance_group.kube.instances)
}

# Data about a node including it's network interface and ip
data "google_compute_instance" "node" {
  count     = local.cluster_node_num
  self_link = local.kube_nodes[count.index]
}

resource "google_dns_record_set" "kube_dns" {
  count        = local.cluster_node_num
  managed_zone = google_dns_managed_zone.dns_zone.name
  name         = "challenges-cluster-node-${count.index}.${var.internal_dns_zone_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [data.google_compute_instance.node[count.index].network_interface[0].network_ip]
}

# Create hosted-challenges namespace
resource "kubernetes_namespace" "hosted_challenges" {
  metadata {
    name = "hosted-challenges"
  }
}

# Install ingress-nginx to route traffic to web-based stateful challenges
resource "helm_release" "nginx_ingress" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true
  depends_on       = [google_container_node_pool.kube_node_pool]
}