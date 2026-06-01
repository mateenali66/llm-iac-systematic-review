variable "domain_name" {
  type    = string
  default = "mycompany.com"
}

variable "alb_dns_name" {
  type = string
}

variable "alb_zone_id" {
  type = string
}

resource "aws_route53_zone" "this" {
  name = var.domain_name

  tags = {
    Name        = var.domain_name
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.this.zone_id
  name    = "app.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}