terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "internal-jump-host"
      ManagedBy   = "Terraform"
      Environment = "prod"
    }
  }
}

variable "vpc_id" {
  description = "VPC ID where the jump host and VPC Endpoints will be deployed."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet ID for the jump host."
  type        = string
}

variable "vpce_subnet_ids" {
  description = "List of private subnet IDs to place the SSM interface endpoints. If empty, uses the jump host subnet."
  type        = list(string)
  default     = []
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair name for break-glass SSH access (not required for SSM)."
  type        = string
  default     = null
}

locals {
  vpce_subnets = length(var.vpce_subnet_ids) > 0 ? var.vpce_subnet_ids : [var.subnet_id]
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_iam_role" "jump_host" {
  name               = "jump-host-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "jump-host-ssm-role"
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jump_host.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jump_host" {
  name = "jump-host-instance-profile"
  role = aws_iam_role.jump_host.name
}

resource "aws_security_group" "jump_host" {
  name        = "sg-jump-host"
  description = "Security group for internal jump host (no inbound; restricted egress)."
  vpc_id      = var.vpc_id

  tags = {
    Name = "sg-jump-host"
  }
}

# Egress: allow SSH to private subnets within VPC
resource "aws_vpc_security_group_egress_rule" "jump_ssh_vpc" {
  security_group_id = aws_security_group.jump_host.id
  description       = "Allow SSH to private subnets in VPC"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = data.aws_vpc.this.cidr_block
}

# Egress: allow HTTPS to VPC for Interface Endpoints and internal services
resource "aws_vpc_security_group_egress_rule" "jump_https_vpc" {
  security_group_id = aws_security_group.jump_host.id
  description       = "Allow HTTPS to VPC (VPC Endpoints, internal APIs)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = data.aws_vpc.this.cidr_block
}

# Egress: allow DNS to VPC resolver
resource "aws_vpc_security_group_egress_rule" "jump_dns_tcp" {
  security_group_id = aws_security_group.jump_host.id
  description       = "Allow DNS TCP to VPC"
  ip_protocol       = "tcp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.this.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "jump_dns_udp" {
  security_group_id = aws_security_group.jump_host.id
  description       = "Allow DNS UDP to VPC"
  ip_protocol       = "udp"
  from_port         = 53
  to_port           = 53
  cidr_ipv4         = data.aws_vpc.this.cidr_block
}

# Egress: allow IMDSv2 token retrieval
resource "aws_vpc_security_group_egress_rule" "jump_imds" {
  security_group_id = aws_security_group.jump_host.id
  description       = "Allow IMDSv2 token retrieval"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "169.254.169.254/32"
}

# Optional: allow ICMP within VPC for troubleshooting (e.g., ping)
resource "aws_vpc_security_group_egress_rule" "jump_icmp_vpc" {
  security_group_id = aws_security_group.jump_host.id
  description       = "Allow ICMP to VPC"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  cidr_ipv4         = data.aws_vpc.this.cidr_block
}

# Security group for Interface VPC Endpoints (restrict to jump host SG)
resource "aws_security_group" "vpce" {
  name        = "sg-vpce-ssm"
  description = "SG for SSM interface VPC Endpoints (ingress 443 from jump host)"
  vpc_id      = var.vpc_id

  tags = {
    Name = "sg-vpce-ssm"
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpce_https_from_jump" {
  security_group_id = aws_security_group.vpce.id
  description       = "Allow HTTPS from jump host to VPC endpoints"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  referenced_security_group_id = aws_security_group.jump_host.id
}

resource "aws_vpc_security_group_egress_rule" "vpce_all_egress" {
  security_group_id = aws_security_group.vpce.id
  description       = "Allow all egress from VPC endpoints"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Interface VPC Endpoints for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]

  tags = {
    Name = "vpce-ssm"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]

  tags = {
    Name = "vpce-ssmmessages"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.us-east-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnets
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce.id]

  tags = {
    Name = "vpce-ec2messages"
  }
}

resource "aws_instance" "jump_host" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.subnet_id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.jump_host.id]
  iam_instance_profile        = aws_iam_instance_profile.jump_host.name
  key_name                    = var.ssh_key_name
  monitoring                  = true

  credit_specification {
    cpu_credits = "unlimited"
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  disable_api_termination = true

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail

    # Minimal updates; avoid full upgrade to reduce downtime during provisioning
    dnf -y update-minimal --security || true

    # Harden SSH (although inbound SSH is not exposed; used for internal hops)
    sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\\?X11Forwarding .*/X11Forwarding no/' /etc/ssh/sshd_config
    if ! grep -q "^ClientAliveInterval" /etc/ssh/sshd_config; then
      echo "ClientAliveInterval 300" >> /etc/ssh/sshd_config
    fi
    if ! grep -q "^ClientAliveCountMax" /etc/ssh/sshd_config; then
      echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config
    fi
    if ! grep -q "^AllowTcpForwarding" /etc/ssh/sshd_config; then
      echo "AllowTcpForwarding yes" >> /etc/ssh/sshd_config
    else
      sed -i 's/^AllowTcpForwarding .*/AllowTcpForwarding yes/' /etc/ssh/sshd_config
    fi
    if ! grep -q "^GatewayPorts" /etc/ssh/sshd_config; then
      echo "GatewayPorts no" >> /etc/ssh/sshd_config
    else
      sed -i 's/^GatewayPorts .*/GatewayPorts no/' /etc/ssh/sshd_config
    fi
    systemctl restart sshd

    # Ensure SSM agent is running (preinstalled on AL2023)
    systemctl enable --now amazon-ssm-agent || true

    # Login banner
    cat >/etc/motd <<'BANNER'
    Authorized access only. All activity may be monitored and logged.
    Use this bastion host for administrative access to private resources only.
    BANNER
  EOF

  tags = {
    Name = "internal-jump-host"
    Role = "bastion"
  }

  depends_on = [
    aws_vpc_endpoint.ssm,
    aws_vpc_endpoint.ssmmessages,
    aws_vpc_endpoint.ec2messages
  ]
}