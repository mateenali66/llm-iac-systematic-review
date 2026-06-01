terraform {
  required_version = ">= 1.5.0"

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
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "application_name" {
  description = "Name of the Elastic Beanstalk application"
  type        = string
  default     = "nodejs-app"
}

variable "environment_name" {
  description = "Name of the Elastic Beanstalk environment"
  type        = string
  default     = "nodejs-app-prod"
}

variable "vpc_id" {
  description = "VPC ID where the environment will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EC2 instances"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the load balancer"
  type        = list(string)
}

variable "ssl_certificate_arn" {
  description = "ARN of the ACM SSL certificate for HTTPS"
  type        = string
  default     = ""
}

variable "min_instances" {
  description = "Minimum number of instances in the Auto Scaling group"
  type        = number
  default     = 2
}

variable "max_instances" {
  description = "Maximum number of instances in the Auto Scaling group"
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "beanstalk_ec2" {
  name               = "${var.application_name}-beanstalk-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "beanstalk_web_tier" {
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "beanstalk_multicontainer_docker" {
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

resource "aws_iam_role_policy_attachment" "beanstalk_worker_tier" {
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.beanstalk_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "beanstalk_ec2" {
  name = "${var.application_name}-beanstalk-ec2-profile"
  role = aws_iam_role.beanstalk_ec2.name
  tags = var.tags
}

data "aws_iam_policy_document" "service_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "beanstalk_service" {
  name               = "${var.application_name}-beanstalk-service-role"
  assume_role_policy = data.aws_iam_policy_document.service_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "service_enhanced_health" {
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "service_managed_updates" {
  role       = aws_iam_role.beanstalk_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}

resource "aws_elastic_beanstalk_application" "this" {
  name        = var.application_name
  description = "Node.js 18 application managed by Terraform"

  appversion_lifecycle {
    service_role          = aws_iam_role.beanstalk_service.arn
    max_count             = 50
    delete_source_from_s3 = true
  }

  tags = var.tags
}

data "aws_elastic_beanstalk_solution_stack" "nodejs" {
  most_recent = true
  name_regex  = "^64bit Amazon Linux 2023 (.*) running Node.js 18$"
}

resource "aws_elastic_beanstalk_environment" "this" {
  name                = var.environment_name
  application         = aws_elastic_beanstalk_application.this.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.nodejs.name
  tier                = "WebServer"

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws