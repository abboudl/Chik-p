variable "vpc_network" {
  type = string
}

variable "dmz_subnet_id" {
  type    = string
  default = "dmz-subnet"
}

variable "dmz_subnet_ip_range" {
  type    = string
  default = "10.10.10.0/24"
}

variable "internal_subnet_id" {
  type    = string
  default = "internal-subnet"
}

variable "internal_subnet_ip_range" {
  type    = string
  default = "10.10.20.0/24"
}

variable "internal_hosted_challenges_subnet_id" {
  type    = string
  default = "hosted-challenges-cluster-subnet"
}

variable "internal_hosted_challenges_subnet_ip_range" {
  type    = string
  default = "10.10.30.0/24"
}

variable "internal_dns_zone_id" {
  type = string
}

variable "internal_dns_zone_domain" {
  type = string
}