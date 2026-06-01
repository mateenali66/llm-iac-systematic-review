data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_ebs_volume" "database_data" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 100
  type              = "gp3"
  iops              = 4000
  throughput        = 250
  encrypted         = true

  tags = {
    Name        = "database-data-volume"
    Environment = "production"
    Backup      = "true"
    ManagedBy   = "Terraform"
  }
}