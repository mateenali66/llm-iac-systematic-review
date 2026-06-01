terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.1"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used for naming resources"
  type        = string
  default     = "node-beanstalk"
}

variable "environment_name" {
  description = "Deployment environment name (e.g., prod, staging)"
  type        = string
  default     = "prod"
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
  description = "List of public subnet IDs for load balancer"
  type        = list(string)
}

variable "min_size" {
  description = "Minimum number of instances in the Auto Scaling Group"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in the Auto Scaling Group"
  type        = number
  default     = 4
}

variable "instance_type" {
  description = "EC2 instance type for Elastic Beanstalk"
  type        = string
  default     = "t3.small"
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS on ALB (optional)"
  type        = string
  default     = ""
}

variable "health_check_path" {
  description = "Application health check path for the ALB target group"
  type        = string
  default     = "/"
}

variable "environment_vars" {
  description = "Environment variables for the application"
  type        = map(string)
  default     = {}
}

variable "node_platform_version" {
  description = "Elastic Beanstalk platform version for Node.js 18 on AL2"
  type        = string
  default     = "5.8.4"
}

locals {
  name_prefix  = "${var.project_name}-${var.environment_name}"
  platform_arn = "arn:aws:elasticbeanstalk:${data.aws_region.current.name}::platform/Node.js 18 running on 64bit Amazon Linux 2/${var.node_platform_version}"
  tags = {
    Project     = var.project_name
    Environment = var.environment_name
    ManagedBy   = "Terraform"
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

resource "aws_security_group" "instances" {
  name        = "${local.name_prefix}-instances-sg"
  description = "Instance security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = local.tags
}

# IAM - Service Role for Elastic Beanstalk
resource "aws_iam_role" "eb_service" {
  name               = "${local.name_prefix}-eb-service-role"
  assume_role_policy = data.aws_iam_policy_document.eb_service_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "eb_service_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "eb_service_enhanced_health" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "eb_service_managed_updates" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}

resource "aws_iam_role_policy_attachment" "eb_service_service" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

# IAM - Instance Role and Profile
resource "aws_iam_role" "eb_instance" {
  name               = "${local.name_prefix}-eb-instance-role"
  assume_role_policy = data.aws_iam_policy_document.eb_instance_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "eb_instance_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "eb_instance_webtier" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_instance_ssm" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "eb_instance_cwagent" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "eb_instance_profile" {
  name = "${local.name_prefix}-eb-instance-profile"
  role = aws_iam_role.eb_instance.name
  tags = local.tags
}

# Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "app" {
  name        = local.name_prefix
  description = "Elastic Beanstalk application for ${local.name_prefix}"

  appversion_lifecycle {
    service_role          = aws_iam_role.eb_service.arn
    max_count             = 50
    delete_source_from_s3 = true
  }

  tags = local.tags
}

# Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "env" {
  name                = "${local.name_prefix}-env"
  application         = aws_elastic_beanstalk_application.app.name
  platform_arn        = local.platform_arn

  # Capacity
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = tostring(var.min_size)
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = tostring(var.max_size)
  }

  # Launch configuration
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance_profile.name
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.instances.id
  }

  # VPC and Subnets
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.private_subnet_ids)
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", var.public_subnet_ids)
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  # Load Balancer and Target Group (ALB)
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = aws_security_group.alb.id
  }
  setting {
    namespace = "aws:elbv2:listener:80"
    name      = "ListenerEnabled"
    value     = "true"
  }
  # Optionally enable HTTPS by adding certificate_arn and related settings manually if desired.

  setting {
    namespace = "aws:elbv2:targetgroup:default"
    name      = "HealthCheckPath"
    value     = var.health_check_path
  }
  setting {
    namespace = "aws:elbv2:targetgroup:default"
    name      = "MatcherHTTPCode"
    value     = "200-399"
  }

  # Enhanced health monitoring
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # Managed platform updates
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "Sun:10:00"
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service.arn
  }
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "UpdateLevel"
    value     = "patch"
  }

  # Rolling deployments
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Rolling"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSizeType"
    value     = "Percentage"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "BatchSize"
    value     = "30"
  }

  # CloudWatch Logs streaming
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "14"
  }

  # Service role for environment (for enhanced health)
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service.arn
  }

  # Application environment variables
  dynamic "setting" {
    for_each = var.environment_vars
    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.eb_service_enhanced_health,
    aws_iam_role_policy_attachment.eb_service_managed_updates,
    aws_iam_role_policy_attachment.eb_service_service,
    aws_iam_role_policy_attachment.eb_instance_webtier,
    aws_iam_role_policy_attachment.eb_instance_ssm,
    aws_iam_role_policy_attachment.eb_instance_cwagent
  ]
}