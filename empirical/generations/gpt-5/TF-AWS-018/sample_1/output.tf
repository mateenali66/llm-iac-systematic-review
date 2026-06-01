terraform {
  required_version = ">= 1.5.0"

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
  description = "AWS region where the ALB is deployed."
  type        = string
}

variable "hosted_zone_name" {
  description = "Root domain for the public hosted zone."
  type        = string
  default     = "mycompany.com"

  validation {
    condition     = can(regex("^(?=.{1,253}$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))*\\.?$", var.hosted_zone_name))
    error_message = "hosted_zone_name must be a valid DNS name."
  }
}

variable "record_subdomain" {
  description = "Subdomain label for the app record (e.g., 'app')."
  type        = string
  default     = "app"

  validation {
    condition     = can(regex("^(?!-)[A-Za-z0-9-]{1,63}(?<!-)$", var.record_subdomain))
    error_message = "record_subdomain must be a valid DNS label (1-63 chars, alphanumeric or hyphen, not starting/ending with hyphen)."
  }
}

variable "alb_name" {
  description = "Name of the existing Application Load Balancer to alias the record to."
  type        = string

  validation {
    condition     = length(var.alb_name) > 0
    error_message = "alb_name cannot be empty."
  }
}

variable "tags" {
  description = "Common tags to apply."
  type        = map(string)
  default     = {}
}

data "aws_lb" "app" {
  name = var.alb_name
}

resource "aws_route53_zone" "primary" {
  name    = trim(var.hosted_zone_name, ".")
  comment = "Public hosted zone for ${trim(var.hosted_zone_name, ".")}"

  force_destroy = false

  tags = merge(
    {
      Name        = trim(var.hosted_zone_name, ".")
      ManagedBy   = "Terraform"
      Environment = "prod"
    },
    var.tags
  )

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  fqdn = "${var.record_subdomain}.${aws_route53_zone.primary.name}"
}

resource "aws_route53_record" "app_a" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app_aaaa" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = local.fqdn
  type    = "AAAA"

  alias {
    name                   = data.aws_lb.app.dns_name
    zone_id                = data.aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

output "hosted_zone_id" {
  description = "ID of the created Route 53 hosted zone."
  value       = aws_route53_zone.primary.zone_id
}

output "app_record_fqdn" {
  description = "Fully qualified domain name for the app record."
  value       = local.fqdn
}

output "nameservers" {
  description = "Nameservers for the hosted zone (add these at your domain registrar)."
  value       = aws_route53_zone.primary.name_servers
}