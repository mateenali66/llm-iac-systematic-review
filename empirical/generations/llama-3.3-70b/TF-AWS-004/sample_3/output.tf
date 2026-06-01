provider "aws" {
  region = "us-west-2"
}

resource "aws_key_pair" "example" {
  key_name   = "example-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC8te8ZV9a5Xs8v8rFJ7XK9uZbJOTsV2r4rIaupGl5ZCf5y6ZGwH1cK6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h5K6o8h example@example.com"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "example" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "example2" {
  vpc_id            = aws_vpc.example.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"
}

resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.example.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.example.id
  }
}

resource "aws_route_table_association" "example" {
  subnet_id      = aws_subnet.example.id
  route_table_id = aws_route_table.example.id
}

resource "aws_route_table_association" "example2" {
  subnet_id      = aws_subnet.example2.id
  route_table_id = aws_route_table.example.id
}

resource "aws_security_group" "example" {
  name        = "example-sg"
  description = "Allow HTTPS traffic"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "HTTPS"
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

resource "aws_security_group" "example_alb" {
  name        = "example-alb-sg"
  description = "Allow HTTPS traffic to ALB"
  vpc_id      = aws_vpc.example.id

  ingress {
    description = "HTTPS"
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

resource "aws_lb" "example" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.example_alb.id]
  subnets            = [aws_subnet.example.id, aws_subnet.example2.id]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:us-west-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.example.id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    path                 = "/"
    interval            = 10
  }
}

resource "aws_launch_template" "example" {
  name          = "example-lt"
  image_id      = "ami-0c94855ba95c71c99"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.example.key_name
  vpc_security_group_ids = [aws_security_group.example.id]

  user_data = base64encode(<<EOF
#!/bin/bash
sudo apt update
sudo apt install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
EOF
)
}

resource "aws_autoscaling_group" "example" {
  name                = "example-asg"
  max_size            = 8
  min_size            = 2
  desired_capacity    = 3
  vpc_zone_identifier = [aws_subnet.example.id, aws_subnet.example2.id]
  target_group_arns   = [aws_lb_target_group.example.arn]

  launch_template {
    id      = aws_launch_template.example.id
    version = "$Latest"
  }
}