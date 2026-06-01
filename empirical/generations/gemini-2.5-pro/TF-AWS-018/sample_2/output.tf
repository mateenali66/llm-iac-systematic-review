terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "domain_name" {
  description = "The domain name for which to create the Route 53 hosted zone."
  type        = string
  default     = "mycompany.com"
}

variable "app_record_name" {
  description = "The subdomain for the application A record (e.g., 'app' for 'app.mycompany.com')."
  type        = string
  default     = "app"
}

variable "alb_name" {
  description = "The name of the existing Application Load Balancer to point the A record to."
  type        = string
}

data "aws_lb" "application" {
  name = var.alb_name
}

resource "aws_route53_zone" "primary" {
  name = var.domain_name

  tags = {
    Name        = var.domain_name
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.app_record_name
  type    = "A"

  alias {
    name                   = data.aws_lb.application.dns_name
    zone_id                = data.aws_lb.application.zone_id
    evaluate_target_health = true
  }
}