variable "domain_name" {
  description = "The domain name for the Route 53 hosted zone."
  type        = string
  default     = "mycompany.com"
}

variable "subdomain_name" {
  description = "The subdomain for the application A record."
  type        = string
  default     = "app"
}

variable "alb_name" {
  description = "The name of the Application Load Balancer to point the A record to."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

locals {
  record_name = "${var.subdomain_name}.${var.domain_name}"
}

data "aws_lb" "app" {
  name = var.alb_name
}

resource "aws_route53_zone" "primary" {
  name = var.domain_name

  tags = var.tags
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = local.record_name
  type    = "A"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id
    evaluate_target_health = true
  }
}