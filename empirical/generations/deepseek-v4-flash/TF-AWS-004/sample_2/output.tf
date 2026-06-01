resource "aws_lb" "web" {
  name               = "web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = true

  tags = {
    Name = "web-alb"
  }
}

resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    port                = "traffic-port"
  }

  tags = {
    Name = "web-tg"
  }
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_security_group" "alb" {
  name        = "web-alb-sg"
  description = "Security group for web ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from internet"
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

  tags = {
    Name = "web-alb-sg"
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-lt-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = base64encode(var.user_data_script)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "web-instance"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "instance" {
  name        = "web-instance-sg"
  description = "Security group for web instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTPS from ALB"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-instance-sg"
  }
}

resource "aws_autoscaling_group" "web" {
  name               = "web-asg"
  vpc_zone_identifier = var.private_subnet_ids
  min_size           = 2
  max_size           = 8
  desired_capacity   = 3
  health_check_type  = "ELB"
  health_check_grace_period = 300
  target_group_arns  = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ASG instances"
  type        = list(string)
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "certificate_arn" {
  description = "ARN of SSL/TLS certificate for HTTPS listener"
  type        = string
}

variable "user_data_script" {
  description = "User data script to bootstrap instances"
  type        = string
  default     = ""
}