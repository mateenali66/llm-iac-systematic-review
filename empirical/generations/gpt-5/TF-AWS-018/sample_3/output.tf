terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain name to create a public hosted zone for"
  type        = string
  default     = "mycompany.com"
}

variable "app_subdomain" {
  description = "Subdomain for the application"
  type        = string
  default     = "app"
}

variable "vpc_id" {
  description = "VPC ID where the ALB will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "health_check_path" {
  description = "Health check path for the target group"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {
    Environment = "prod"
  }
}

locals {
  app_fqdn = "${var.app_subdomain}.${var.domain_name}"
  tags = merge(
    {
      Project   = "mycompany-app"
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_route53_zone" "primary" {
  name          = var.domain_name
  comment       = "Public hosted zone for ${var.domain_name}"
  force_destroy = false

  tags = local.tags
}

resource "aws_security_group" "alb" {
  name        = "${var.app_subdomain}-alb-sg"
  description = "Security group for ${local.app_fqdn} ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

resource "aws_lb" "app" {
  name                       = "${var.app_subdomain}-alb"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = true
  ip_address_type            = "dualstack"
  idle_timeout               = 60

  tags = local.tags
}

resource "aws_lb_target_group" "app" {
  name        = "${var.app_subdomain}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.tags
}

resource "aws_acm_certificate" "app" {
  domain_name       = local.app_fqdn
  validation_method = "DNS"

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "app" {
  certificate_arn         = aws_acm_certificate.app.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2018-06"
  certificate_arn   = aws_acm_certificate_validation.app.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = local.tags
}

resource "aws_route53_record" "app_a" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = local.app_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "app_aaaa" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = local.app_fqdn
  type    = "AAAA"

  alias {
    name                   = aws_lb.app.dns_name
    zone_id                = aws_lb.app.zone_id
    evaluate_target_health = true
  }
}

output "hosted_zone_id" {
  description = "Hosted zone ID for the root domain"
  value       = aws_route53_zone.primary.zone_id
}

output "app_fqdn" {
  description = "FQDN for the application"
  value       = aws_route53_record.app_a.fqdn
}

output "alb_dns_name" {
  description = "DNS name of the created Application Load Balancer"
  value       = aws_lb.app.dns_name
}