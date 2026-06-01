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
    ManagedBy   = "Terraform"
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

  deletion_protection_enabled = true

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "user-sessions"
    Environment = var.environment
    Purpose     = "Application session storage"
    ManagedBy   = "Terraform"
  }
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "production"
}

output "table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.user_sessions.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.user_sessions.arn
}

output "table_stream_arn" {
  description = "ARN of the Table Stream (if enabled)"
  value       = aws_dynamodb_table.user_sessions.stream_arn
}