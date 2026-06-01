terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_kms_key" "dynamodb" {
  description             = "KMS key for encrypting DynamoDB user-sessions table"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "user-sessions-dynamodb-kms"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_kms_alias" "dynamodb" {
  name          = "alias/dynamodb-user-sessions"
  target_key_id = aws_kms_key.dynamodb.key_id
}

resource "aws_dynamodb_table" "user_sessions" {
  name         = "user-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  deletion_protection_enabled = true

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb.arn
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "user-sessions"
    Environment = var.environment
    ManagedBy   = "terraform"
    Purpose     = "application-session-storage"
  }
}

variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

output "table_name" {
  description = "Name of the DynamoDB user-sessions table"
  value       = aws_dynamodb_table.user_sessions.name
}

output "table_arn" {
  description = "ARN of the DynamoDB user-sessions table"
  value       = aws_dynamodb_table.user_sessions.arn
}

output "table_id" {
  description = "ID of the DynamoDB user-sessions table"
  value       = aws_dynamodb_table.user_sessions.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for table encryption"
  value       = aws_kms_key.dynamodb.arn
}