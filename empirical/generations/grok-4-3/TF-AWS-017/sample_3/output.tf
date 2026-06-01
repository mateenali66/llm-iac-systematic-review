resource "aws_ebs_volume" "db" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true
  iops              = 3000
  throughput        = 125
  tags = {
    Name        = "db-ebs"
    Environment = "production"
    Backup      = "snapshot-enabled"
  }
}