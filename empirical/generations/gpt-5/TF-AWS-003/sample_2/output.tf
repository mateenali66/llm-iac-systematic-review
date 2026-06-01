terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.35.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC where the jump host will be deployed"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet for the jump host"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into the jump host"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "assign_eip" {
  description = "Whether to allocate and associate an Elastic IP to the jump host"
  type        = bool
  default     = true
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 20
}

variable "kms_key_id" {
  description = "KMS Key ID/ARN for EBS encryption (optional). If null, uses AWS-managed key"
  type        = string
  default     = null
}

variable "instance_name" {
  description = "Name tag for the jump host instance"
  type        = string
  default     = "internal-jump-host"
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge(
    {
      Name        = var.instance_name
      Environment = "prod"
      Role        = "jump-host"
    },
    var.tags
  )
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "jump" {
  name        = "${var.instance_name}-sg"
  description = "Security group for internal jump host (SSH access restricted)"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { "Name" = "${var.instance_name}-sg" })
}

resource "aws_security_group_rule" "jump_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.jump.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  description       = "Allow all egress (package updates, outbound SSH)"
}

resource "aws_security_group_rule" "jump_ingress_ssh" {
  count             = length(var.allowed_ssh_cidrs) > 0 ? 1 : 0
  type              = "ingress"
  security_group_id = aws_security_group.jump.id
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.allowed_ssh_cidrs
  description       = "Restrict SSH access to approved CIDRs"
}

resource "aws_iam_role" "jump" {
  name               = "${var.instance_name}-role"
  assume_role_policy = data.aws_iam_policy_document.jump_trust.json

  tags = local.common_tags
}

data "aws_iam_policy_document" "jump_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.jump.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "jump" {
  name = "${var.instance_name}-instance-profile"
  role = aws_iam_role.jump.name

  tags = local.common_tags
}

resource "aws_instance" "jump" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = "t3.medium"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jump.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.jump.name
  associate_public_ip_address = true
  monitoring                  = true
  ebs_optimized               = true
  disable_api_termination     = true

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size_gb
    encrypted   = true
    kms_key_id  = var.kms_key_id
    iops        = 3000
    throughput  = 125
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = <<-EOT
    #!/usr/bin/env bash
    set -euo pipefail

    # Update system
    dnf -y update

    # Harden SSH configuration
    SSHD_CONFIG="/etc/ssh/sshd_config"
    cp -a "${SSHD_CONFIG}" "${SSHD_CONFIG}.bak.$(date +%s)"

    # Disable root login and password auth; allow agent and TCP forwarding for jump usage
    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' "${SSHD_CONFIG}"
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "${SSHD_CONFIG}"
    sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "${SSHD_CONFIG}"
    sed -i 's/^#\?UseDNS.*/UseDNS no/' "${SSHD_CONFIG}"
    sed -i 's/^#\?X11Forwarding.*/X11Forwarding no/' "${SSHD_CONFIG}"

    if ! grep -q "^AllowAgentForwarding" "${SSHD_CONFIG}"; then
      echo "AllowAgentForwarding yes" >> "${SSHD_CONFIG}"
    else
      sed -i 's/^AllowAgentForwarding.*/AllowAgentForwarding yes/' "${SSHD_CONFIG}"
    fi

    if ! grep -q "^AllowTcpForwarding" "${SSHD_CONFIG}"; then
      echo "AllowTcpForwarding yes" >> "${SSHD_CONFIG}"
    else
      sed -i 's/^AllowTcpForwarding.*/AllowTcpForwarding yes/' "${SSHD_CONFIG}"
    fi

    if ! grep -q "^ClientAliveInterval" "${SSHD_CONFIG}"; then
      echo "ClientAliveInterval 300" >> "${SSHD_CONFIG}"
    else
      sed -i 's/^ClientAliveInterval.*/ClientAliveInterval 300/' "${SSHD_CONFIG}"
    fi

    if ! grep -q "^ClientAliveCountMax" "${SSHD_CONFIG}"; then
      echo "ClientAliveCountMax 2" >> "${SSHD_CONFIG}"
    else
      sed -i 's/^ClientAliveCountMax.*/ClientAliveCountMax 2/' "${SSHD_CONFIG}"
    fi

    systemctl restart sshd

    # Ensure SSM agent is enabled (preinstalled on AL2023)
    systemctl enable --now amazon-ssm-agent || true

    # Basic fail2ban install and enable for sshd (optional hardening)
    dnf -y install fail2ban
    systemctl enable --now fail2ban

    # Log successful provisioning
    echo "Jump host bootstrap completed at $(date -Is)" | systemd-cat -t jump-bootstrap -p info
  EOT

  tags = local.common_tags
}

resource "aws_eip" "jump" {
  count  = var.assign_eip ? 1 : 0
  domain = "vpc"
  instance = aws_instance.jump.id

  tags = merge(local.common_tags, { "Name" = "${var.instance_name}-eip" })
}