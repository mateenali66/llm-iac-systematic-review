provider "aws" {
  region = var.aws_region
}

locals {
  name   = "webapp-prod"
  vpc_id = aws_vpc.main.id
  tags = {
    Project       = "WebApp"
    Environment   = "Production"
    ManagedBy     = "Terraform"
    ResourceGroup = local.name
  }
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for the web servers."
  type        = string
  default     = "t3.micro"
}

variable "certificate_domain_name" {
  description = "The domain name for which to find a certificate in ACM."
  type        = string
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_acm_certificate" "this" {
  domain      = var.certificate_domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.tags
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name = "${local.name}-public-${count.index + 1