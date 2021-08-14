# Wireguard Host Static External Public IP
resource "google_compute_address" "wireguard_external_ip" {
  name         = "wireguard-external-static-ip"
  address_type = "EXTERNAL"
  network_tier = var.network_tier
}

# Wireguard Host Internal IP
resource "google_compute_address" "wireguard_internal_ip" {
  name         = "wireguard-internal-static-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.dmz_subnet.id
  address      = var.wg_internal_ip
}

# Create wireguard A Record
resource "google_dns_record_set" "wireguard_dns" {
  managed_zone = google_dns_managed_zone.dns_zone.name
  name         = "${var.wg_internal_hostname}.${var.internal_dns_zone_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.wg_internal_ip]
}

# Get external Public IP
data "google_compute_address" "wg_public_ip" {
  name = google_compute_address.wireguard_external_ip.name
}

# Create Wireguard Host
resource "google_compute_instance" "wireguard_instance" {
  name           = var.wg_host_id
  description    = "VM instance will host Wireguard Gateway."
  hostname       = "${var.wg_internal_hostname}.${var.internal_dns_zone_domain}"
  machine_type   = var.wg_machine_type
  tags           = ["wireguard-server"]
  can_ip_forward = true

  boot_disk {
    device_name = "wireguard"

    initialize_params {
      image = var.wg_machine_image
      size  = var.wg_machine_disk_size
      type  = var.wg_machine_disk_type
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz_subnet.id
    network_ip = var.wg_internal_ip

    access_config {
      network_tier = var.network_tier
      nat_ip       = data.google_compute_address.wg_public_ip.address
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

# Firewall: Allow Access to VPN
resource "google_compute_firewall" "allow_vpn" {
  name          = "allow-vpn"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = "1000"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }

  target_tags = ["wireguard-server"]
}

# Set up GCP Static Route Back to VPN Gateway
resource "google_compute_route" "vpn_route" {
  name                   = "vpn-route-to-virtual-client-network"
  network                = google_compute_network.vpc_network.id
  next_hop_instance      = google_compute_instance.wireguard_instance.name
  next_hop_instance_zone = var.gcp_zone
  dest_range             = var.wg_client_subnet
  priority               = 1000

}