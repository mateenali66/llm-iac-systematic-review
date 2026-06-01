resource "aws_dynamodb_table" "user_sessions" {
  name         = "user-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  table_class  = "STANDARD"

  attribute {
    name = "session_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  ttl {
    attribute_name = "ttl_expiry"
    enabled        = true
  }

  tags = {
    Name      = "user-sessions"
    ManagedBy = "Terraform"
  }
}