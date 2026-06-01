terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources in."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment (e.g., prod, staging)."
  default     = "prod"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources."
  default     = {}
}

variable "ttl_attribute" {
  type        = string
  description = "DynamoDB TTL attribute name (epoch time in seconds)."
  default     = "ttl"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Application = "user-sessions"
        Environment = var.environment
        ManagedBy   = "Terraform"
      },
      var.tags
    )
  }
}

resource "aws_dynamodb_table" "user_sessions" {
  name                        = "user-sessions"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "session_id"
  deletion_protection_enabled = true

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}