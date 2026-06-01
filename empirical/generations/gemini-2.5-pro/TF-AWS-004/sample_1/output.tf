#
# Terraform Configuration for a High-Availability Web Application
#
# This configuration provisions the following resources:
# - A new VPC with public and private subnets across two Availability Zones.
# - An Internet Gateway for public subnet internet access.
# - A NAT Gateway for private subnet outbound internet access.
# - An Application Load Balancer (ALB) to distribute traffic.
# - An Auto Scaling Group of EC2 instances in the private subnets.
# - Security Groups to control traffic between the components.
# - An IAM Role for the EC2 instances with SSM permissions.
#

################################################################################
# Provider and Data Sources
################################################################################

provider "aws" {
  region = var.aws_region
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

# Note: This assumes a certificate for the specified domain already exists in ACM.
# Certificate creation and validation are not handled by this Terraform code.
data "aws_acm_certificate" "this" {
  domain   = var.acm_certificate_domain
  statuses = ["ISSUED"]
}

################################################################################