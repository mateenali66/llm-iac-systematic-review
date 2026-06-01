variable "domain_name" {
  description = "The custom domain name for the static website (e.g., www.example.com)."
  type        = string
}

variable "zone_name" {
  description = "The name of the Route 53 hosted zone that contains the domain (e.g., example.com)."
  type        = string