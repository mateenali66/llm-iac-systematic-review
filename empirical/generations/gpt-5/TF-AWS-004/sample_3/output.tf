terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project/application name used for tagging and naming"
  type        = string
  default     = "webapp"
}

variable "vpc_cidr" {
  description = "CIDR for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to use (minimum 2 recommended)"
  type        = number
  default     = 2
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be between 2 and 3."
  }
}

variable "acm_certificate_arn" {
  description = "Existing ACM certificate ARN for HTTPS. If not provided, domain_name and hosted_zone_id must be set to create and validate a new certificate."
  type        = string
  default     = ""
  validation {
    condition     = (length(var.acm_certificate_arn) > 0) || ((length(var.domain_name) > 0) && (length(var.hosted_zone_id) > 0))
    error_message = "Provide either acm_certificate_arn OR both domain_name and hosted_zone_id."
  }
}

variable "domain_name" {
  description = "Domain name for ACM certificate (used if acm_certificate_arn is not provided)"
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for DNS validation (used if acm_certificate_arn is not provided)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type for the Auto Scaling Group"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name for SSH access (optional)"
  type        = string
  default     = ""
}

variable "desired_capacity" {
  description = "Desired number of instances"
  type        = number
  default     = 3
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 8
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs                   = slice(data.aws_availability_zones.available.names, 0, var.az_count)
  public_subnet_cidrs   = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  private_subnet_cidrs  = [for i in range(var.az_count) : cidrsubnet(var.vpc_cidr, 4, i + 16)]
  name_prefix           = "${var.project_name}"
  common_tags = {
    Project = var.project_name
    Managed = "terraform"
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  for_each = { for idx, az in local.azs : az => {
    az   = az
    cidr = local.public_subnet_cidrs[idx]
  } }

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in local.azs : az => {
    az   = az
    cidr = local.private_subnet_cidrs[idx]
  } }

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-eip-nat-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each      = aws_subnet.public
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-rt-${each.key}"
  })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP for redirect to HTTPS"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from anywhere"
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.alb.id
  description       = "Allow all egress"
}

resource "aws_security_group" "asg" {
  name        = "${local.name_prefix}-asg-sg"
  description = "Security group for ASG instances"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-asg-sg"
  })
}

resource "aws_security_group_rule" "asg_ingress_http_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = aws_security_group.asg.id
  description              = "Allow HTTP from ALB only"
}

resource "aws_security_group_rule" "asg_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = aws_security_group.asg.id
  description       = "Allow all egress"
}

# ACM certificate (optional creation with DNS validation)
resource "aws_acm_certificate" "this" {
  count               = length(var.acm_certificate_arn) == 0 && length(var.domain_name) > 0 && length(var.hosted_zone_id) > 0 ? 1 : 0
  domain_name         = var.domain_name
  validation_method   = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-cert"
  })
}

resource "aws_route53_record" "cert_validation" {
  for_each = length(aws_acm_certificate.this) > 0 ? {
    for dvo in aws_acm_certificate.this[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "this" {
  count                   = length(aws_acm_certificate.this) > 0 ? 1 : 0
  certificate_arn         = aws_acm_certificate.this[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

locals {
  certificate_arn = length(var.acm_certificate_arn) > 0 ? var.acm_certificate_arn : (
    length(aws_acm_certificate_validation.this) > 0 ? aws_acm_certificate_validation.this[0].certificate_arn : ""
  )
}

resource "aws_lb" "this" {
  name                       = "${local.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [for s in aws_subnet.public : s.id]
  enable_deletion_protection = true
  idle_timeout               = 60

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb"
  })
}

resource "aws_lb_target_group" "this" {
  name     = "${local.name_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    path                = "/"
    matcher             = "200-399"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-tg"
  })
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  depends_on = [aws_acm_certificate_validation.this]
}

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

resource "aws_iam_role" "ec2" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-role"
  })
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2.name

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-ec2-instance-profile"
  })
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail

    dnf -y update
    dnf -y install nginx

    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!doctype html>
    <html>
    <head><title>${local.name_prefix} app</title></head>
    <body>
      <h1>${local.name_prefix} - It works!</h1>
      <p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
      <p>AZ: $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</p>
    </body>
    </html>
    HTML

    systemctl enable nginx
    systemctl start nginx

    # Harden SSH (optional - no SSH exposed by SG)
    sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config || true
    systemctl restart sshd || true
  EOT
}

resource "aws_launch_template" "this" {
  name_prefix   = "${local.name_prefix}-lt-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [aws_security_group.asg.id]

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-ec2"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-ec2-volume"
    })
  }

  user_data = base64encode(local.user_data)
}

resource "aws_autoscaling_group" "this" {
  name                      = "${local.name_prefix}-asg"
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  vpc_zone_identifier       = [for s in aws_subnet.private : s.id]
  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  wait_for_elb_capacity     = var.min_size
  capacity_rebalance        = true

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-ec2"
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
}

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${local.name_prefix}-asg-cpu-tt"
  autoscaling_group_name = aws_autoscaling_group.this.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50
  }
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_https_url" {
  description = "HTTPS URL of the load balancer"
  value       = "https://${aws_lb.this.dns_name}"
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.this.name
}