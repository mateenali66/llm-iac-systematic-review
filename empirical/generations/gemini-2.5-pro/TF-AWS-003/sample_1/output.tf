terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "trusted_ssh_cidr_blocks" {
  type        = list(string)
  description = "List of trusted CIDR blocks for SSH access to the jump host (e.g., corporate office IPs)."
  default     = ["0.0.0.0/0"] # WARNING: This is insecure. Replace with your specific IP range in a .tfvars file.
}

variable "engineer_public_key" {
  type        = string
  description = "The public SSH key for the key pair used to access the jump host."
  sensitive   = true
}

locals {
  name_prefix = "internal-jump-host"
  common_tags = {
    ManagedBy   = "Terraform"
    Project     = "Internal-Tools"
    Environment = "production"
  }
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(