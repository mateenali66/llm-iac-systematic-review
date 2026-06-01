resource "aws_route53_zone" "mycompany" {
  name = "mycompany.com"
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.mycompany.zone_id
  name    = "app.mycompany.com"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

variable "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  type        = string
}

variable "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  type        = string
}

output "hosted_zone_id" {
  value = aws_route53_zone.mycompany.zone_id
}

output "name_servers" {
  value = aws_route53_zone.mycompany.name_servers
}