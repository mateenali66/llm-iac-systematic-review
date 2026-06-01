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
  description = "Availability zone where the EBS volume will be created. Must match the EC2 instance AZ."
  type        = string
}

variable "instance_id" {
  description = "ID of the EC2 database instance to attach the volume to."
  type        = string
}

variable "device_name" {
  description = "Device name for the EBS volume attachment."
  type        = string
  default     = "/dev/sdf"
}

variable "environment" {
  description = "Deployment environment (e.g., prod, staging)."
  type        = string
  default     = "prod"
}

variable "backup_retention_days" {
  description = "Number of days to retain EBS snapshots."
  type        = number
  default     = 30
}

variable "snapshot_schedule_cron" {
  description = "Cron expression for the DLM snapshot schedule (UTC)."
  type        = string
  default     = "cron(0 3 * * ? *)"
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "ebs" {
  description             = "KMS key for encrypting EBS database volume and snapshots"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name        = "ebs-database-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/ebs-database-${var.environment}"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_ebs_volume" "database" {
  availability_zone = var.availability_zone
  size              = 100
  type              = "gp3"
  iops              = 3000
  throughput        = 125
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn

  tags = {
    Name        = "database-volume-${var.environment}"
    Environment = var.environment
    Role        = "database"
    Backup      = "true"
    Snapshot    = "daily"
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

resource "aws_iam_role" "dlm_lifecycle" {
  name = "dlm-lifecycle-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "dlm.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  name = "dlm-lifecycle-policy-${var.environment}"
  role = aws_iam_role.dlm_lifecycle.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*::snapshot/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ]
        Resource = aws_kms_key.ebs.arn
      }
    ]
  })
}

resource "aws_dlm_lifecycle_policy" "database_snapshots" {
  description        = "Snapshot lifecycle policy for database EBS volume"
  execution_role_arn = aws_iam_role.dlm_lifecycle.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "Daily database snapshots"

      create_rule {
        cron_expression = var.snapshot_schedule_cron
      }

      retain_rule {
        count = var.backup_retention_days
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Environment     = var.environment
      }

      copy_tags = true
    }

    target_tags = {
      Backup = "true"
    }
  }

  tags = {
    Environment = var.environment
  }
}

output "volume_id" {
  description = "ID of the created EBS volume."
  value       = aws_ebs_volume.database.id
}

output "volume_arn" {
  description = "ARN of the created EBS volume."
  value       = aws_ebs_volume.database.arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for EBS encryption."
  value       = aws_kms_key.ebs.arn
}

output "dlm_policy_id" {
  description = "ID of the DLM lifecycle policy managing snapshots."
  value       = aws_dlm_lifecycle_policy.database_snapshots.id
}