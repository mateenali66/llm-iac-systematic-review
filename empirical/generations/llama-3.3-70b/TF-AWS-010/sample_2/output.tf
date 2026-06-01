resource "aws_dynamodb_table" "user_sessions" {
  name           = "user-sessions"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  tags = {
    Name        = "user-sessions"
    Environment = "production"
  }
}