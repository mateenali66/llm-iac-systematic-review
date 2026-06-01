terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to use for Route 53 operations (global service, but provider still requires a region)."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment tag for resources."
  type        = string
  default     = "prod"
}

variable "domain_name" {
  description = "Root domain to provision the hosted zone for."
  type        = string
  default     = "mycompany.com"

  validation {
    condition     = can(regex("^[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.domain_name))
    error_message = "domain_name must be a valid DNS name like example.com."
  }
}

variable "app_alb_name" {
  description = "Name of the existing Application Load Balancer to alias app.<domain> to."
  type        = string
}

resource "aws_route53_zone" "primary" {
  name    = var.domain_name
  comment = "Public hosted zone for ${var.domain_name}"

  tags = {
    Name        = var.domain_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_lb" "app" {
  name = var.app_alb_name
}

resource "aws_route53_record" "app_alias_a" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id
    evaluate_target_health = true
  }

  allow_overwrite = true
}

resource "aws_route53_record" "app_alias_aaaa" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "app.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id
    evaluate_target_health = true
  }

  allow_overwrite = true
}

output "hosted_zone_id" {
  description = "ID of the created Route 53 hosted zone."
  value       = aws_route53_zone.primary.zone_id
}

output "name_servers" {
  description = "Name servers for the created hosted zone."
  value       = aws_route53_zone.primary.name_servers
}

output "app_record_fqdn" {
  description = "FQDN for the app record."
  value       = aws_route53_record.app_alias_a.fqdn
}