# Create Virtual Private Cloud (VPC)
resource "google_compute_network" "vpc_network" {
  name                    = var.vpc_network
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  mtu                     = 1460
}

# Create Subnets
resource "google_compute_subnetwork" "dmz_subnet" {
  name          = var.dmz_subnet_id
  ip_cidr_range = var.dmz_subnet_ip_range
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "internal_subnet" {
  name          = var.internal_subnet_id
  ip_cidr_range = var.internal_subnet_ip_range
  network       = google_compute_network.vpc_network.id
}

resource "google_compute_subnetwork" "internal_hosted_challenges_subnet" {
  name          = var.internal_hosted_challenges_subnet_id
  ip_cidr_range = var.internal_hosted_challenges_subnet_ip_range
  network       = google_compute_network.vpc_network.id
}

# Create a Cloud Router and setup NAT to allow private VMs to reach internet
resource "google_compute_router" "nat_router" {
  name    = "nat-router"
  network = google_compute_network.vpc_network.name
}

resource "google_compute_router_nat" "nat_config" {
  name                               = "nat-config"
  router                             = google_compute_router.nat_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# Configure Basic Firewall Rules (ICMP and SSH)
resource "google_compute_firewall" "allow_ssh" {
  name          = "allow-ssh"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = "65534"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "allow_icmp" {
  name          = "allow-icmp"
  network       = google_compute_network.vpc_network.name
  direction     = "INGRESS"
  priority      = "65534"
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }
}

# Create Managed Cloud DNS Zone
resource "google_dns_managed_zone" "dns_zone" {
  name        = var.internal_dns_zone_id
  description = "Private DNS Zone for ISSessionsCTF Infrastructure."
  dns_name    = "${var.internal_dns_zone_domain}."
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc_network.id
    }
  }
}

# Create Inbound Forwarding Policy to Allow VPN Clients (On-Prem) to Query GCP Private DNS Zones
resource "google_dns_policy" "dns_policy" {
  name                      = "allow-on-prem-to-query-gcp-dns-policy"
  description               = "This policy allows VPN clients to query the private DNS zone of the GCP ISSessionsCTF environment."
  enable_inbound_forwarding = true

  networks {
    network_url = google_compute_network.vpc_network.id
  }
}