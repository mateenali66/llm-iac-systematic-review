terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "availability_zone" {
  description = "Availability zone where the EBS volume will be created. Must match the EC2 instance's AZ."
  type        = string
}

variable "instance_id" {
  description = "ID of the EC2 database instance to attach the volume to."
  type        = string
}

variable "device_name" {
  description = "Device name for the EBS volume attachment."
  type        = string
  default     = "/dev/xvdf"
}

variable "environment" {
  description = "Deployment environment (e.g., prod, staging)."
  type        = string
  default     = "prod"
}

variable "kms_key_id" {
  description = "KMS key ARN used to encrypt the EBS volume. If null, the AWS-managed default EBS key is used."
  type        = string
  default     = null
}

variable "backup_schedule" {
  description = "Cron expression for the DLM snapshot schedule (UTC)."
  type        = string
  default     = "cron(0 5 ? * * *)"
}

variable "snapshot_retention_count" {
  description = "Number of snapshots to retain in the DLM lifecycle policy."
  type        = number
  default     = 14
}

resource "aws_ebs_volume" "database" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true
  kms_key_id        = var.kms_key_id

  tags = {
    Name        = "db-data-volume"
    Environment = var.environment
    Role        = "database"
    Backup      = "true"
    Snapshot    = "daily"
    ManagedBy   = "terraform"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [snapshot_id]
  }
}

resource "aws_volume_attachment" "database" {
  device_name                    = var.device_name
  volume_id                      = aws_ebs_volume.database.id
  instance_id                    = var.instance_id
  stop_instance_before_detaching = true
}

data "aws_iam_policy_document" "dlm_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["dlm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "dlm_lifecycle" {
  name               = "dlm-lifecycle-role-database"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume_role.json

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_iam_policy_document" "dlm_lifecycle" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSnapshot",
      "ec2:CreateSnapshots",
      "ec2:DeleteSnapshot",
      "ec2:DescribeInstances",
      "ec2:DescribeVolumes",
      "ec2:DescribeSnapshots",
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*::snapshot/*"]
  }
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  name   = "dlm-lifecycle-policy-database"
  role   = aws_iam_role.dlm_lifecycle.id
  policy = data.aws_iam_policy_document.dlm_lifecycle.json
}

resource "aws_dlm_lifecycle_policy" "database_snapshots" {
  description        = "Daily snapshot lifecycle policy for database EBS volume"
  execution_role_arn = aws_iam_role.dlm_lifecycle.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    target_tags = {
      Backup = "true"
      Role   = "database"
    }

    schedule {
      name = "Daily Snapshots"

      create_rule {
        cron_expression = var.backup_schedule
      }

      retain_rule {
        count = var.snapshot_retention_count
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Environment     = var.environment
      }

      copy_tags = true
    }
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

output "volume_id" {
  description = "ID of the database EBS volume."
  value       = aws_ebs_volume.database.id
}

output "volume_arn" {
  description = "ARN of the database EBS volume."
  value       = aws_ebs_volume.database.arn
}

output "dlm_policy_id" {
  description = "ID of the DLM lifecycle policy managing snapshots."
  value       = aws_dlm_lifecycle_policy.database_snapshots.id
}