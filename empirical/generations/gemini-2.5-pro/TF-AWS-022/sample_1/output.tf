terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
  required_version = ">= 1.3"
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project, used for tagging and naming resources."
  type        = string
  default     = "app-cache"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "cache_node_type" {
  description = "The instance type for the ElastiCache nodes."
  type        = string
  default     = "cache.t3.micro"
}

variable "cache_node_count" {
  description = "The total number of nodes in the cluster (1 primary + N replicas)."
  type        = number
  default     = 3
}

variable "redis_version" {
  description = "The version of the Redis engine to use."
  type        = string
  default     = "7.1"
}

locals {
  tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Environment = "Production"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.