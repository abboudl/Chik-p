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

variable "wg_host_id" {
  type = string
}

variable "wg_internal_hostname" {
  type    = string
  default = "wireguard"
}

variable "wg_internal_ip" {
  type    = string
  default = "10.10.10.7"
}

variable "wg_machine_type" {
  type    = string
  default = "e2-small"
}

variable "wg_machine_image" {
  type    = string
  default = "ubuntu-os-cloud/ubuntu-2004-focal-v20210720"
}

variable "wg_machine_disk_type" {
  type    = string
  default = "pd-standard"
}

variable "wg_machine_disk_size" {
  type    = number
  default = 20
}

variable "wg_protocol" {
  type    = string
  default = "udp"
}

variable "wg_port" {
  type    = string
  default = "51820"
}

variable "wg_client_subnet" {
  type    = string
  default = "10.13.13.0/24"
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

variable "nginx" {
  type = object({
    host_id           = string
    internal_hostname = string
    internal_ip       = string
    machine_type      = string
    machine_image     = string
    machine_disk_type = string
    machine_disk_size = number
  })

  default = {
    host_id           = "nginx-int-ctf-issessions-ca"
    internal_hostname = "nginx" # will be prepended to .$internal_dns_zone_domain to form fqdn
    internal_ip       = "10.10.10.8"
    machine_type      = "e2-custom-2-4096"
    machine_image     = "ubuntu-os-cloud/ubuntu-2004-focal-v20210720"
    machine_disk_type = "pd-standard"
    machine_disk_size = 20
  }
}

variable "ctfd" {
  type = object({
    host_id           = string
    internal_hostname = string
    internal_ip       = string
    machine_type      = string
    machine_image     = string
    machine_disk_type = string
    machine_disk_size = number
  })

  default = {
    host_id           = "ctfd-int-ctf-issessions-ca"
    internal_hostname = "ctfd" # will be prepended to .$internal_dns_zone_domain to form fqdn
    internal_ip       = "10.10.20.49"
    machine_type      = "e2-standard-4"
    machine_image     = "ubuntu-os-cloud/ubuntu-2004-focal-v20210720"
    machine_disk_type = "pd-ssd"
    machine_disk_size = 200
  }
}

variable "haproxy" {
  type = object({
    host_id           = string
    internal_hostname = string
    internal_ip       = string
    machine_type      = string
    machine_image     = string
    machine_disk_type = string
    machine_disk_size = number
  })

  default = {
    host_id           = "haproxy-int-ctf-issessions-ca"
    internal_hostname = "haproxy" # will be prepended to .$internal_dns_zone_domain to form fqdn
    internal_ip       = "10.10.10.9"
    machine_type      = "e2-highcpu-2"
    machine_image     = "ubuntu-os-cloud/ubuntu-2004-focal-v20210720"
    machine_disk_type = "pd-standard"
    machine_disk_size = 20
  }
}

variable "kube" {
  type = object({
    cluster_id              = string
    cluster_pool_id         = string
    cluster_k8s_version     = string
    cluster_release_channel = string
    cluster_node_num        = number
    cluster_machine_type    = string
    cluster_image_type      = string
    cluster_disk_type       = string
    cluster_disk_size       = number
    namespace               = string
  })

  default = {
    cluster_id              = "hosted-challenges-cluster"
    cluster_pool_id         = "hosted-challenges-pool"
    cluster_k8s_version     = "1.18.17-gke.700"
    cluster_release_channel = "STABLE"
    cluster_node_num        = 3
    cluster_machine_type    = "e2-custom-2-16384"
    cluster_image_type      = "cos_containerd"
    cluster_disk_type       = "pd-standard"
    cluster_disk_size       = 50
    namespace               = "hosted-challenges"
  }
}