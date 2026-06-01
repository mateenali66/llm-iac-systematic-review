terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "webapp"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_count" {
  type    = number
  default = 3
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the ALB HTTPS listener"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "desired_capacity" {
  type    = number
  default = 3
}

variable "min_size" {
  type    = number
  default = 2
}

variable "max_size" {
  type    = number
  default = 8
}

variable "health_check_path" {
  type    = string
  default = "/"
}

variable "tags" {
  type    = map(string)
  default = {}
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnet_cidrs = [
    for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i)
  ]

  private_subnet_cidrs = [
    for i in range(length(local.azs)) : cidrsubnet(var.vpc_cidr, 4, i + 8)
  ]

  tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "Terraform"
    },
    var.tags
  )
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, { Name = "${var.project_name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, { Name = "${var.project_name}-igw" })
}

resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.tags, { Name = "${var.project_name}-public-${local.azs[count.index]}" })
}

resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]

  tags = merge(local.tags, { Name = "${var.project_name}-private-${local.azs[count.index]}" })
}

resource "aws_eip" "nat" {
  count  = length(local.azs)
  domain = "vpc"

  tags = merge(local.tags, { Name = "${var.project_name}-nat-eip-${local.azs[count.index]}" })
}

resource "aws_nat_gateway" "this" {
  count         = length(local.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.tags, { Name = "${var.project_name}-natgw-${local.azs[count.index]}" })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  count  = length(local.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.tags, { Name = "${var.project_name}-public-rt-${local.azs[count.index]}" })
}

resource "aws_route_table_association" "public" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

resource "aws_route_table" "private" {
  count  = length(local.azs)
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }

  tags = merge(local.tags, { Name = "${var.project_name}-private-rt-${local.azs[count.index]}" })
}

resource "aws_route_table_association" "private" {
  count          = length(local.azs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-alb-sg" })
}

resource "aws_security_group" "instance" {
  name        = "${var.project_name}-instance-sg"
  description = "Instance security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description              = "Allow HTTP from ALB"
    from_port                = 80
    to_port                  = 80
    protocol                 = "tcp"
    security_groups          = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.project_name}-instance-sg" })
}

resource "aws_lb_target_group" "app" {
  name_prefix = "tg-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.this.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = var.health_check_path
    matcher             = "200-399"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    protocol            = "HTTP"
    port                = "traffic-port"
  }

  tags = merge(local.tags, { Name = "${var.project_name}-tg" })
}

resource "aws_lb" "app" {
  name_prefix                = "alb-"
  load_balancer_type         = "application"
  internal                   = false
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for s in aws_subnet.public : s.id]
  idle_timeout               = 60
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  tags = merge(local.tags, { Name = "${var.project_name}-alb" })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
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
}

resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_launch_template" "app" {
  name_prefix   = "lt-"
  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type
  update_default_version = true

  vpc_security_group_ids = [aws_security_group.instance.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 16
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf -y update
    dnf -y install httpd
    systemctl enable --now httpd
    cat >/var/www/html/index.html <<'HTML'
    <!doctype html>
    <html lang="en">
      <head><meta charset="utf-8"><title>${var.project_name}</title></head>
      <body><h1>${var.project_name} is running</h1></body>
    </html>
    HTML
  EOT
  )

  tag_specifications {
    resource_type = "instance"

    tags = merge(local.tags, { Name = "${var.project_name}-ec2" })
  }

  tag_specifications {
    resource_type = "volume"

    tags = local.tags
  }

  tags = local.tags
}

resource "aws_autoscaling_group" "app" {
  name_prefix               = "asg-"
  vpc_zone_identifier       = [for s in aws_subnet.private : s.id]
  desired_capacity          = var.desired_capacity
  min_size                  = var.min_size
  max_size                  = var.max_size
  health_check_type         = "ELB"
  health_check_grace_period = 300
  capacity_rebalance        = true

  target_group_arns = [aws_lb_target_group.app.arn]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  termination_policies = ["OldestLaunchTemplate", "Default"]

  metrics_granularity = "1Minute"
  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ec2"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_lb_listener.https]
}