resource "aws_ebs_volume" "db_data" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.ebs_kms_key_id

  tags = {
    Name        = "db-data"
    Environment = var.environment
    Backup      = "enabled"
    Snapshot    = "daily"
  }
}