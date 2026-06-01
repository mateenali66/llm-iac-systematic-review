terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Name tag for the bastion instance and related resources"
  type        = string
  default     = "bastion-jump-host"
}

variable "vpc_id" {
  description = "VPC ID where the bastion will reside"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the bastion (public subnet if using EIP)"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the existing EC2 Key Pair to use for SSH access"
  type        = string
}

variable "allowed_ssh_cidr_blocks" {
  description = "List of allowed IPv4 CIDR blocks for SSH access to the bastion"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_ipv6_cidr_blocks" {
  description = "List of allowed IPv6 CIDR blocks for SSH access to the bastion"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_security_group_ids" {
  description = "List of security group IDs allowed to SSH to the bastion"
  type        = list(string)
  default     = []
}

variable "allowed_egress_cidr_blocks" {
  description = "List of allowed IPv4 CIDR blocks for egress from the bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_egress_ipv6_cidr_blocks" {
  description = "List of allowed IPv6 CIDR blocks for egress from the bastion"
  type        = list(string)
  default     = ["::/0"]
}

variable "attach_eip" {
  description = "Whether to allocate and attach an Elastic IP to the bastion (requires public subnet + IGW)"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "ebs_kms_key_id" {
  description = "Optional KMS Key ID/ARN for EBS encryption (defaults to AWS managed key if null)"
  type        = string
  default     = null
}

variable "disable_api_termination" {
  description = "Enable termination protection for the bastion instance"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}-sg"
  description = "Security group for bastion jump host"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name      = "${var.name}-sg"
    Component = "bastion"
  })
}

resource "aws_security_group_rule" "ssh_ingress_ipv4" {
  count             = length(var.allowed_ssh_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.bastion.id
  cidr_blocks       = var.allowed_ssh_cidr_blocks
  description       = "Allow SSH from approved IPv4 CIDRs"
}

resource "aws_security_group_rule" "ssh_ingress_ipv6" {
  count             = length(var.allowed_ssh_ipv6_cidr_blocks) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.bastion.id
  ipv6_cidr_blocks  = var.allowed_ssh_ipv6_cidr_blocks
  description       = "Allow SSH from approved IPv6 CIDRs"
}

resource "aws_security_group_rule" "ssh_ingress_sg" {
  for_each                 = toset(var.allowed_ssh_security_group_ids)
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.bastion.id
  source_security_group_id = each.value
  description              = "Allow SSH from trusted security group ${each.value}"
}

resource "aws_security_group_rule" "egress_ipv4" {
  count             = length(var.allowed_egress_cidr_blocks) > 0 ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.bastion.id
  cidr_blocks       = var.allowed_egress_cidr_blocks
  description       = "Allow all outbound IPv4 traffic"
}

resource "aws_security_group_rule" "egress_ipv6" {
  count             = length(var.allowed_egress_ipv6_cidr_blocks) > 0 ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.bastion.id
  ipv6_cidr_blocks  = var.allowed_egress_ipv6_cidr_blocks
  description       = "Allow all outbound IPv6 traffic"
}

resource "aws_iam_role" "bastion" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, {
    Name      = "${var.name}-role"
    Component = "bastion"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.bastion.name

  tags = merge(var.tags, {
    Name      = "${var.name}-instance-profile"
    Component = "bastion"
  })
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.medium"
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  key_name               = var.ssh_key_name
  monitoring             = true
  disable_api_termination = var.disable_api_termination

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    iops                  = 3000
    throughput            = 125
    encrypted             = true
    kms_key_id            = var.ebs_kms_key_id
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail

    dnf -y update

    # Harden SSH configuration
    SSHD_CONFIG="/etc/ssh/sshd_config"
    sed -i 's/^[#[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    sed -i 's/^[#[:space:]]*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
    sed -i 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    sed -i 's/^[#[:space:]]*UseDNS.*/UseDNS no/' "$SSHD_CONFIG"

    if grep -q '^AllowTcpForwarding' "$SSHD_CONFIG"; then
      sed -i 's/^[#[:space:]]*AllowTcpForwarding.*/AllowTcpForwarding yes/' "$SSHD_CONFIG"
    else
      echo "AllowTcpForwarding yes" >> "$SSHD_CONFIG"
    fi

    if grep -q '^ClientAliveInterval' "$SSHD_CONFIG"; then
      sed -i 's/^[#[:space:]]*ClientAliveInterval.*/ClientAliveInterval 300/' "$SSHD_CONFIG"
    else
      echo "ClientAliveInterval 300" >> "$SSHD_CONFIG"
    fi

    if grep -q '^ClientAliveCountMax' "$SSHD_CONFIG"; then
      sed -i 's/^[#[:space:]]*ClientAliveCountMax.*/ClientAliveCountMax 2/' "$SSHD_CONFIG"
    else
      echo "ClientAliveCountMax 2" >> "$SSHD_CONFIG"
    fi

    systemctl restart sshd

    # Ensure SSM agent is enabled and running
    systemctl enable --now amazon-ssm-agent || true

    # Install useful troubleshooting tools
    dnf -y install jq tcpdump bind-utils
  EOT
  )

  tags = merge(var.tags, {
    Name       = var.name
    Role       = "bastion"
    ManagedBy  = "Terraform"
    OS         = "Amazon Linux 2023"
    Component  = "bastion"
    Backup     = "false"
    Confidentiality = "internal"
  })
}

resource "aws_eip" "bastion" {
  count  = var.attach_eip ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name      = "${var.name}-eip"
    Component = "bastion"
  })
}

resource "aws_eip_association" "bastion" {
  count         = var.attach_eip ? 1 : 0
  allocation_id = aws_eip.bastion[0].id
  instance_id   = aws_instance.bastion.id
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "ID of the bastion instance"
}

output "bastion_private_ip" {
  value       = aws_instance.bastion.private_ip
  description = "Private IP of the bastion instance"
}

output "bastion_public_ip" {
  value       = var.attach_eip ? aws_eip.bastion[0].public_ip : aws_instance.bastion.public_ip
  description = "Public IP of the bastion instance (if any)"
}

output "bastion_security_group_id" {
  value       = aws_security_group.bastion.id
  description = "Security group ID attached to the bastion"
}