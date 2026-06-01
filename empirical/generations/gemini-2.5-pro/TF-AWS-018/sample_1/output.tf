variable "domain_name" {
  description = "The domain name for which to create the Route 53 hosted zone."
  type        = string
  default     = "mycompany.com"
}

variable "app_subdomain" {
  description = "The subdomain for the application A record (e.g., 'app')."
  type        = string
  default     = "app"
}

variable "alb_name" {
  description = "The name of the Application Load Balancer to point the A record to."
  type        = string
}

data "aws_lb" "app" {
  name = var.alb_name
}

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = {
    Name      = var.domain_name
    ManagedBy = "Terraform"
  }
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id
    evaluate_target_health = true
  }
}