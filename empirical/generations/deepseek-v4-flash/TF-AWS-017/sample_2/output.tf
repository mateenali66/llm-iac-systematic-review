resource "aws_ebs_volume" "database" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true

  tags = {
    Name = "database-ebs-volume"
  }
}

resource "aws_volume_attachment" "database" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.database.id
  instance_id = var.instance_id
}

resource "aws_ebs_snapshot" "database_backup" {
  volume_id = aws_ebs_volume.database.id

  tags = {
    Name = "database-ebs-snapshot"
  }
}

resource "aws_ebs_snapshot_copy" "database_backup_cross_region" {
  source_snapshot_id = aws_ebs_snapshot.database_backup.id
  source_region      = var.aws_region

  tags = {
    Name = "database-ebs-snapshot-cross-region"
  }
}

variable "availability_zone" {
  description = "The availability zone for the EBS volume"
  type        = string
}

variable "instance_id" {
  description = "The ID of the EC2 instance to attach the volume"
  type        = string
}

variable "aws_region" {
  description = "The AWS region for the snapshot copy"
  type        = string
}