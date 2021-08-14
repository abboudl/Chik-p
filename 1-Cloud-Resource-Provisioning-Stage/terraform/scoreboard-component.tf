# Nginx Host Static External Public IP
resource "google_compute_address" "nginx_external_ip" {
  name         = "nginx-external-static-ip"
  address_type = "EXTERNAL"
  network_tier = var.network_tier
}

# Nginx Host Internal IP
resource "google_compute_address" "nginx_internal_ip" {
  name         = "nginx-internal-static-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.dmz_subnet.id
  address      = var.nginx.internal_ip
}

# CTFd Host Internal IP
resource "google_compute_address" "ctfd_internal_ip" {
  name         = "ctfd-internal-static-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.internal_subnet.id
  address      = var.ctfd.internal_ip
}

# Create nginx A Record
resource "google_dns_record_set" "nginx_dns" {
  managed_zone = google_dns_managed_zone.dns_zone.name
  name         = "${var.nginx.internal_hostname}.${var.internal_dns_zone_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.nginx.internal_ip]
}

# Create ctfd A Record
resource "google_dns_record_set" "ctfd_dns" {
  managed_zone = google_dns_managed_zone.dns_zone.name
  name         = "${var.ctfd.internal_hostname}.${var.internal_dns_zone_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = [var.ctfd.internal_ip]
}

# Get nginx Public IP
data "google_compute_address" "nginx_public_ip" {
  name = google_compute_address.nginx_external_ip.name
}

# Create nginx Host
resource "google_compute_instance" "nginx_instance" {
  name         = var.nginx.host_id
  description  = "VM instance will host ISSessionsCTF Nginx container acting as a reverse proxy to CTFd."
  hostname     = "${var.nginx.internal_hostname}.${var.internal_dns_zone_domain}"
  machine_type = var.nginx.machine_type
  tags         = ["nginx-server"]

  boot_disk {
    device_name = "nginx"

    initialize_params {
      image = var.nginx.machine_image
      size  = var.nginx.machine_disk_size
      type  = var.nginx.machine_disk_type
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.dmz_subnet.id
    network_ip = var.nginx.internal_ip

    access_config {
      network_tier = var.network_tier
      nat_ip       = data.google_compute_address.nginx_public_ip.address
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

# Create ctfd Host
resource "google_compute_instance" "ctfd_instance" {
  name         = var.ctfd.host_id
  description  = "VM instance will host ISSessionsCTF CTFd containers including the CTFd Flask application, a MariaDB MySQL database, and a Redis cache."
  hostname     = "${var.ctfd.internal_hostname}.${var.internal_dns_zone_domain}"
  machine_type = var.ctfd.machine_type
  tags         = ["ctfd-server"]

  boot_disk {
    device_name = "ctfd"

    initialize_params {
      image = var.ctfd.machine_image
      size  = var.ctfd.machine_disk_size
      type  = var.ctfd.machine_disk_type
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.internal_subnet.id
    network_ip = var.ctfd.internal_ip
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

# Allow HTTP Access to Nginx
resource "google_compute_firewall" "nginx_http" {
  name          = "nginx-allow-http-80"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = "1000"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["nginx-server"]
}

# Allow HTTPS Access to Nginx
resource "google_compute_firewall" "nginx_https" {
  name          = "nginx-allow-https-443"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = "1000"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  target_tags = ["nginx-server"]
}

# Allow Communication Between Nginx and CTFD
resource "google_compute_firewall" "nginx_to_ctfd" {
  name          = "allow-nginx-to-ctfd"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = "1000"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
  source_tags = ["ctfd-server"]
  target_tags = ["nginx-server"]
}