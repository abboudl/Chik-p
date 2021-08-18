variable "google_project" {
  type = string
}

variable "google_region" {
  type = string
}

variable "google_zone" {
  type = string
}

variable "api" {
  type = list(string)

  default = [
    "compute.googleapis.com",
    "dns.googleapis.com",
    "container.googleapis.com"
  ]

}
