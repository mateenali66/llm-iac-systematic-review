resource "aws_ebs_volume" "database_volume" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"
  iops              = 3000
  throughput        = 125

  tags = {
    Name        = "database-volume"
    Environment = var.environment
    Backup      = "enabled"
  }
}

resource "aws_ebs_snapshot" "database_volume_snapshot" {
  volume_id = aws_ebs_volume.database_volume.id

  tags = {
    Name        = "database-volume-snapshot"
    Environment = var.environment
  }
}