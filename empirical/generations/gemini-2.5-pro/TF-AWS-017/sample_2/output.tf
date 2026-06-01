data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_ebs_volume" "database" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 100
  type              = "gp3"
  encrypted         = true
  iops              = 3000
  throughput        = 125

  tags = {
    Name        = "database-data-volume"
    Environment = "production"
    Service     = "database"
    Backup      = "true"
    ManagedBy   = "Terraform"
  }
}