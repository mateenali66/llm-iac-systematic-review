locals {
  common_tags = {
    Name        = "user-sessions"
    Environment = terraform.workspace
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_key" "dynamodb_user_sessions" {
  description             = "KMS CMK for DynamoDB table user-sessions"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  tags                    = local.common_tags
}

resource "aws_kms_alias" "dynamodb_user_sessions" {
  name          = "alias/dynamodb/user-sessions"
  target_key_id = aws_kms_key.dynamodb_user_sessions.key_id
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
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.dynamodb_user_sessions.arn
  }

  tags = local.common_tags
}