variable "app_name" {
  description = "The name of the Elastic Beanstalk application."
  type        = string
  default     = "nodejs-app"
}

variable "env_name" {
  description = "The name of the Elastic Beanstalk environment."
  type        = string
  default     = "nodejs-app-prod"
}

variable "region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "The ID of the VPC to deploy the environment into."
  type        = string
}

variable "public_subnets" {
  description = "A list of public subnet IDs for the load balancer."
  type        = list(string)
}

variable "private_subnets" {
  description = "A list of private subnet IDs for the EC2 instances."
  type        = list(string)
}

variable "instance_type" {
  description = "The EC2 instance type for the environment."
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "The name of the EC2 key pair for SSH access."
  type        = string
}

variable "ssl_certificate_arn" {
  description = "The ARN of the ACM SSL certificate for HTTPS."
  type        = string
  default     = ""
}

provider "aws" {
  region = var.region
}

locals {
  tags = {
    Application = var.app_name
    Environment = var.env_name
    ManagedBy   = "Terraform"
  }
  https_enabled = var.ssl_certificate_arn != ""
}

data "aws_elastic_beanstalk_solution_stack" "nodejs" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2 v.* running Node.js 18$"
}

resource "aws_iam_role" "beanstalk_ec2_role" {
  name = "${var.app_name}-eb-ec2-role"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "beanstalk_ec2_policy" {
  role       = aws_iam_role.beanstalk_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws