terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Elastic Beanstalk application name"
  type        = string
  default     = "nodejs-app"
}

variable "env_name" {
  description = "Elastic Beanstalk environment name"
  type        = string
  default     = "prod"
}

variable "tags" {
  description = "Common tags to apply to resources"
  type        = map(string)
  default = {
    Project     = "nodejs-eb"
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

locals {
  name_prefix = "${var.app_name}-${var.env_name}"
  tags        = var.tags
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC
resource "aws_vpc" "this" {
  cidr_block           = "10.60.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# Public subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.60.0.0/20"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-a"
  })
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.60.16.0/20"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-b"
  })
}

# Private subnets
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.60.32.0/20"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-a"
  })
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.60.48.0/20"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-b"
  })
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat-eip"
  })
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-nat"
  })
  depends_on = [aws_internet_gateway.igw]
}

# Route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-a-rt"
  })
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(local.tags, {
    Name = "${local.name_prefix}-private-b-rt"
  })
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "ALB security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "instances" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "EC2 instances security group"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.name_prefix}-ec2-sg"
  })
}

# IAM - Elastic Beanstalk service role
data "aws_iam_policy_document" "eb_service_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eb_service" {
  name               = "${local.name_prefix}-eb-service-role"
  assume_role_policy = data.aws_iam_policy_document.eb_service_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "eb_service_enhanced_health" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "eb_service_main" {
  role       = aws_iam_role.eb_service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

# IAM - EC2 instance profile for Beanstalk
data "aws_iam_policy_document" "eb_instance_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eb_instance" {
  name               = "${local.name_prefix}-eb-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.eb_instance_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "eb_instance_webtier" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_role_policy_attachment" "eb_instance_ssm" {
  role       = aws_iam_role.eb_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "eb_instance" {
  name = "${local.name_prefix}-eb-ec2-profile"
  role = aws_iam_role.eb_instance.name
  tags = local.tags
}

# Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "app" {
  name        = var.app_name
  description = "Elastic Beanstalk application for Node.js 18"
  tags        = local.tags
}

# Platform version for Node.js 18 on Amazon Linux 2
data "aws_elastic_beanstalk_platform_version" "nodejs18" {
  platform_name = "Node.js 18 running on 64bit Amazon Linux 2"
  most_recent   = true
}

# Elastic Beanstalk environment
resource "aws_elastic_beanstalk_environment" "env" {
  name                = "${var.app_name}-${var.env_name}"
  application         = aws_elastic_beanstalk_application.app.name
  platform_arn        = data.aws_elastic_beanstalk_platform_version.nodejs18.arn
  wait_for_ready_timeout = "30m"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service.name
  }

  # VPC configuration
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.this.id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.private_a.id, aws_subnet.private_b.id])
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", [aws_subnet.public_a.id, aws_subnet.public_b.id])
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "public"
  }

  # Load Balancer security groups (ALB)
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SecurityGroups"
    value     = aws_security_group.alb.id
  }

  # Auto Scaling group sizes
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "4"
  }

  # Launch configuration
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t3.small"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_instance.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "RootVolumeSize"
    value     = "20"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.instances.id
  }

  # Health checks
  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "HealthCheckURL"
    value     = "/"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # CloudWatch Logs
  setting {
    namespace = "aws:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "true"
  }

  setting {
    namespace = "aws:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = "14"
  }

  setting {
    namespace = "aws:cloudwatch:logs:health"
    name      = "HealthStreamingEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:cloudwatch:logs:health"
    name      = "DeleteOnTerminate"
    value     = "true"
  }

  setting {
    namespace = "aws:cloudwatch:logs:health"
    name      = "RetentionInDays"
    value     = "14"
  }

  # Rolling updates
  setting {
    namespace = "aws:autoscaling:updatepolicy"
    name      = "RollingUpdateEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy"
    name      = "RollingUpdateType"
    value     = "Health"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy"
    name      = "MinInstancesInService"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy"
    name      = "RollingRestartEnabled"
    value     = "true"
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
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  # Use ALB explicitly
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.eb_service_enhanced_health,
    aws_iam_role_policy_attachment.eb_service_main,
    aws_iam_role_policy_attachment.eb_instance_webtier,
    aws_iam_role_policy_attachment.eb_instance_ssm
  ]
}