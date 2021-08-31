provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

variable "cloudflare_api_token" {
  type = string
}

data "cloudflare_zones" "public_dns" {
  filter {
    name = var.public_domain
  }
}

locals {
  zone_id = data.cloudflare_zones.public_dns.zones[0].id
}

# Wireguard Public DNS A Record
resource "cloudflare_record" "wireguard_external_dns" {
  name    = "vpn.${var.public_ctf_subdomain}.${var.public_domain}"
  type    = "A"
  value   = data.google_compute_address.wg_public_ip.address
  zone_id = local.zone_id
}

# Nginx Public DNS A Record
resource "cloudflare_record" "nginx_external_dns" {
  name    = "${var.public_ctf_subdomain}.${var.public_domain}"
  type    = "A"
  value   = data.google_compute_address.nginx_public_ip.address
  zone_id = local.zone_id
}