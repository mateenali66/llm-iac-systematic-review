provider "aws" {
  region = "us-west-2"
}

resource "aws_route53_zone" "mycompany_com" {
  name = "mycompany.com"
}

resource "aws_alb" "mycompany_alb" {
  name               = "mycompany-alb"
  subnets            = [aws_subnet.mycompany_subnet.id]
  security_groups    = [aws_security_group.mycompany_sg.id]
  internal           = false
  load_balancer_type = "application"
}

resource "aws_subnet" "mycompany_subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.mycompany_vpc.id
  availability_zone = "us-west-2a"
}

resource "aws_vpc" "mycompany_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "mycompany_sg" {
  name        = "mycompany-sg"
  description = "Allow HTTP and HTTPS traffic"
  vpc_id      = aws_vpc.mycompany_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route53_record" "app_mycompany_com" {
  zone_id = aws_route53_zone.mycompany_com.id
  name    = "app.mycompany.com"
  type    = "A"

  alias {
    name                   = aws_alb.mycompany_alb.dns_name
    zone_id               = aws_alb.mycompany_alb.zone_id
    evaluate_target_health = false
  }
}