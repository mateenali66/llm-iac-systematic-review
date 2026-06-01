terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain name for the hosted zone"
  type        = string
  default     = "mycompany.com"
}

variable "app_subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "app"
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

resource "aws_route53_zone" "primary" {
  name          = var.domain_name
  comment       = "Primary hosted zone for ${var.domain_name}"
  force_destroy = false

  tags = merge(
    var.tags,
    {
      Name = var.domain_name
    }
  )
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app_ipv6" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "AAAA"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

output "hosted_zone_id" {
  description = "The Route 53 hosted zone ID"
  value       = aws_route53_zone.primary.zone_id
}

output "hosted_zone_name_servers" {
  description = "Name servers for the hosted zone - configure these at your domain registrar"
  value       = aws_route53_zone.primary.name_servers
}

output "app_fqdn" {
  description = "Fully qualified domain name for the application"
  value       = aws_route53_record.app.fqdn
}