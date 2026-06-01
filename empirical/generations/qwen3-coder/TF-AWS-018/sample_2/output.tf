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