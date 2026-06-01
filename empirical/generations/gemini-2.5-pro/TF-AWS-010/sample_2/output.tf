resource "aws_dynamodb_table" "user_sessions" {
  name                        = "user-sessions"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true
  table_class                 = "STANDARD"

  hash_key = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = "alias/aws/dynamodb"
  }

  ttl {
    enabled        = true
    attribute_name = "ttl"
  }

  tags = {
    Name        = "user-sessions"
    Environment = "production"
    ManagedBy   = "Terraform"
  }
}