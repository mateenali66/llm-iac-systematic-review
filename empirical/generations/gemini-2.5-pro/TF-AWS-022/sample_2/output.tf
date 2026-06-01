variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "The deployment environment (e.g., 'prod', 'staging')."
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "The ID of the VPC where the ElastiCache cluster will be deployed."
  type        = string
}

variable "private_subnet_ids" {
  description = "A list of private subnet IDs for the ElastiCache subnet group."
  type        = list(string)
}

variable "redis_auth_token" {
  description = "The authentication token (password) for the Redis cluster. Must be at least 16 characters."
  type        = string
  sensitive   = true
  # In a real scenario, this should be sourced from a secrets manager.
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Security group for application servers that need to access ElastiCache"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-sg"
  })
}

resource "aws_security_group" "elasticache" {
  name        = "${local.name_prefix}-elasticache-sg"
  description = "Security group for the ElastiCache Redis cluster"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow Redis traffic from application servers"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security