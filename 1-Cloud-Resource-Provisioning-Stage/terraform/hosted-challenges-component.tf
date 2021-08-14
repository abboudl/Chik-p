# HAProxy Host Internal IP
resource "google_compute_address" "haproxy_internal_ip" {
  name         = "haproxy-internal-static-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.dmz_subnet.id
  address      = var.haproxy.internal_ip
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
  name         = "${var.haproxy.internal_hostname}.${var.internal_dns_zone_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.haproxy.internal_ip]
}

# Create HAProxy Host
resource "google_compute_instance" "haproxy_instance" {
  name         = var.haproxy.host_id
  description  = "VM instance will host ISSessionsCTF HAProxy container acting as a proxy to TCP-Based Hosted Challenges."
  hostname     = "${var.haproxy.internal_hostname}.${var.internal_dns_zone_domain}"
  machine_type = var.haproxy.machine_type
  tags         = ["haproxy-server"]

  boot_disk {
    device_name = "haproxy"

    initialize_params {
      image = var.haproxy.machine_image
      size  = var.haproxy.machine_disk_size
      type  = var.haproxy.machine_disk_type
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz_subnet.id
    network_ip = var.haproxy.internal_ip

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
  name                     = var.kube.cluster_id
  initial_node_count       = 1
  remove_default_node_pool = true
  network                  = google_compute_network.vpc_network.id
  subnetwork               = google_compute_subnetwork.internal_hosted_challenges_subnet.id
  enable_shielded_nodes    = true

  ip_allocation_policy {}

  release_channel {
    channel = var.kube.cluster_release_channel
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "10.10.100.0/28"

    master_global_access_config {
      enabled = true
    }
  }

  network_policy {
    enabled = true
  }

  master_authorized_networks_config {}

}

resource "google_container_node_pool" "kube_node_pool" {
  name              = var.kube.cluster_pool_id
  cluster           = google_container_cluster.kube_cluster.id
  node_count        = var.kube.cluster_node_num
  max_pods_per_node = 110
  
  node_config {
    disk_type    = var.kube.cluster_disk_type
    disk_size_gb = var.kube.cluster_disk_size
    image_type   = var.kube.cluster_image_type
    machine_type = var.kube.cluster_machine_type
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
