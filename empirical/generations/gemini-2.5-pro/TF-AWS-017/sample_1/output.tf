variable "availability_zone" {
  description = "The Availability Zone in which to create the EBS volume. Must match the AZ of the EC2 instance."
  type        = string
}

variable "db_instance_id" {
  description = "The ID of the EC2 instance to which the volume will be attached."
  type        = string
}

variable "volume_tags" {
  description = "A map of tags to assign to the EBS volume for identification and automation."
  type        = map(string)
  default = {
    "Name"        = "database-data-volume"
    "Environment" = "production"
    "ManagedBy"   = "Terraform"
    "Backup"      = "true"
  }
}

data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}

resource "aws_ebs_volume" "database_data" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true
  kms_key_id        = data.aws_kms_key.ebs.arn

  tags = var.volume_tags
}

resource "aws_volume_attachment" "database_data_attachment" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.database_data.id
  instance_id = var.db_instance_id
}