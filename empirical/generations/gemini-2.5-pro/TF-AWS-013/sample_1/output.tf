provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "The name of the application."
  type        = string
  default     = "my-api"
}

variable "app_environment" {
  description = "The environment (e.g., 'prod', 'staging')."
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "container_image" {
  description = "The Docker image to run in the ECS task."
  type        = string
  default     = "public.ecr.aws/nginx/nginx:1.25" # Replace with your API server image
}

variable "container_port" {
  description = "The port exposed by the container."
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "The path for the load balancer health check."
  type        = string
  default     = "/"
}

variable "task_cpu" {
  description = "The number of CPU units to reserve for the container."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "The amount of memory (in MiB) to reserve for the container."
  type        = number
  default     = 512
}

variable "desired_task_count" {
  description = "The desired number of tasks to run for the service."
  type        = number
  default     = 2
}

variable "acm_certificate_domain" {
  description = "The domain name for which to find an existing ACM certificate."
  type        = string
  # IMPORTANT: Replace this with your domain name
  default = "api.example.com"
}

locals {
  name_prefix = "${var.app_name}-${var.app_environment}"
  tags = {
    Application = var.app_name
    Environment = var.app_environment
    ManagedBy   = "Terraform"
  }
}

#------------------------------------------------------------------------------
# Networking
#------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.tags,
    { Name = "${local.name_prefix}-vpc" }
  )
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.tags,
    { Name = "${local.name_prefix}-public-subnet-${count.index