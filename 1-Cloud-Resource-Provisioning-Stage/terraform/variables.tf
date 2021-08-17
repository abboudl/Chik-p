variable "internal_dns_zone_domain" {
  type = string
}

variable "ansible_public_key_path" {
  type    = string
  default = "~/.ssh/ansible.pub"
}

variable "public_domain" {
  type = string
}

variable "public_ctf_subdomain" {
  type    = string
  default = "ctf"
}

variable "network_tier" {
  type = string
}
