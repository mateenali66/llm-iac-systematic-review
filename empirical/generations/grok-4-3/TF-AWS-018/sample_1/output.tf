variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  type        = string
}

resource "aws_route53_zone" "main" {
  name = "mycompany.com"

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_route53_record" "app_alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.mycompany.com"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}