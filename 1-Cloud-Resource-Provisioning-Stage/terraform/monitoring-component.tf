# ELK Host Internal IP
resource "google_compute_address" "elk_internal_ip" {
  name         = "elk-internal-static-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.internal_subnet.id
  address      = "10.10.20.51"
}

# Create ELK A Record
resource "google_dns_record_set" "elk_dns" {
  managed_zone = google_dns_managed_zone.dns_zone.name
  name         = "elk.${var.internal_dns_zone_domain}."
  type         = "A"
  ttl          = 300
  rrdatas      = ["10.10.20.51"]
}

# Create ELK Host
resource "google_compute_instance" "elk_instance" {
  name         = "elk-int-ctf"
  description  = "VM instance will host an ELK stack to monitor and collect statistics for ISSessiosCTF."
  hostname     = "elk.${var.internal_dns_zone_domain}"
  machine_type = "e2-standard-4"
  tags         = ["elk-server"]

  boot_disk {
    device_name = "elk"

    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-focal-v20210720"
      size  = 200
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.internal_subnet.id
    network_ip = "10.10.20.51"
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

# Allow communication from CTFD Host to ELK Host (Logstash Beats Port 5044)
resource "google_compute_firewall" "ctfd_elk" {
  name      = "allow-ctfd-to-elk-logstash-5044"
  network   = google_compute_network.vpc_network.name
  direction = "INGRESS"
  priority  = "1000"

  allow {
    protocol = "tcp"
    ports    = ["5044"]
  }
  source_tags = ["ctfd-server"]
  target_tags = ["elk-server"]
}

# Allow communication from Nginx Host to ELK Host (Logstash Beats Port 5044)
resource "google_compute_firewall" "nginx_elk" {
  name      = "allow-nginx-to-elk-logstash-5044"
  network   = google_compute_network.vpc_network.name
  direction = "INGRESS"
  priority  = "1000"

  allow {
    protocol = "tcp"
    ports    = ["5044"]
  }
  source_tags = ["nginx-server"]
  target_tags = ["elk-server"]
}

# Allow Communication from VPN to ELK Host (Kibana Port 5601)
resource "google_compute_firewall" "vpn_elk" {
  name      = "allow-vpn-to-elk-kibana-5601"
  network   = google_compute_network.vpc_network.name
  direction = "INGRESS"
  priority  = "1000"

  allow {
    protocol = "tcp"
    ports    = ["5601"]
  }
  source_tags = ["wireguard-server"]
  target_tags = ["elk-server"]
}

# Allow Communication from VPN to ELK Host (Elasticsearch Port 9200) for API calls
resource "google_compute_firewall" "vpn_elk_es" {
  name      = "allow-vpn-to-elk-es-9200"
  network   = google_compute_network.vpc_network.name
  direction = "INGRESS"
  priority  = "1000"

  allow {
    protocol = "tcp"
    ports    = ["9200"]
  }
  source_tags = ["wireguard-server"]
  target_tags = ["elk-server"]
}