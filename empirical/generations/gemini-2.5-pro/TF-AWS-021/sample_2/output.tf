terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for the resources."
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Name of the Elastic Beanstalk application."
  type        = string
  default     = "nodejs-app"
}

variable "env_name" {
  description = "Name of the Elastic Beanstalk environment."
  type        = string
  default     = "nodejs-app-prod"
}

data "aws_elastic_beanstalk_solution_stack" "nodejs" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2 .* running Node.js 18$"
}

resource "aws_elastic_beanstalk_application" "app" {
  name        = var.app_name
  description = "Node.js application"
}

resource "aws_iam_role" "ebs_ec2_role" {
  name = "${var.app_name}-ebs-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_ec2_policy" {
  role       = aws_iam_role.ebs_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "ebs_instance_profile" {
  name = "${var.app_name}-ebs-instance-profile"
  role = aws_iam_role.ebs_ec2_role.name
}

resource "aws_iam_role" "ebs_service_role" {
  name = "${var.app_name}-ebs-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "elasticbeanstalk.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_service_policy" {
  role       = aws_iam_role.ebs