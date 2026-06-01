terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "region" {
  description = "AWS region"
  type        = string
}

provider "aws" {
  region = var.region
}

variable "db_instance_id" {
  description = "EC2 instance ID of the database host"
  type        = string
}

variable "db_instance_az" {
  description = "Availability Zone of the database EC2 instance (the EBS volume must be in the same AZ)"
  type        = string
}

variable "volume_device_name" {
  description = "Device name for the EBS volume attachment (e.g., /dev/sdf)"
  type        = string
  default     = "/dev/sdf"
}

variable "name_prefix" {
  description = "Prefix used for naming resources"
  type        = string
  default     = "db"
}

variable "iops" {
  description = "Provisioned IOPS for gp3 volume"
  type        = number
  default     = 6000
}

variable "throughput" {
  description = "Provisioned throughput (MiB/s) for gp3 volume"
  type        = number
  default     = 250
}

variable "backup_tags" {
  description = "Tags used by the application's snapshot-based backup workflow"
  type        = map(string)
  default = {
    backup = "true"
  }
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}

data "aws_kms_key" "ebs" {
  key_id = "alias/aws/ebs"
}

resource "aws_ebs_volume" "db_data" {
  availability_zone = var.db_instance_az
  size              = 100
  type              = "gp3"
  encrypted         = true
  kms_key_id        = data.aws_kms_key.ebs.arn
  iops              = var.iops
  throughput        = var.throughput

  tags = merge(
    {
      Name      = "${var.name_prefix}-data"
      ManagedBy = "Terraform"
    },
    var.backup_tags,
    var.tags
  )

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_volume_attachment" "db_data" {
  device_name = var.volume_device_name
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = var.db_instance_id
}