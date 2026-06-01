terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region where the EBS volume will be created"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  description = "Availability Zone for the EBS volume. Must match the EC2 instance's AZ."
  type        = string
}

variable "instance_id" {
  description = "ID of the EC2 database instance to attach the volume to"
  type        = string
}

variable "device_name" {
  description = "Device name for the EBS volume attachment"
  type        = string
  default     = "/dev/sdf"
}

variable "environment" {
  description = "Deployment environment (e.g., prod, staging)"
  type        = string
  default     = "prod"
}

variable "application" {
  description = "Application name"
  type        = string
  default     = "database"
}

variable "kms_key_id" {
  description = "KMS key ARN/ID used to encrypt the EBS volume. If null, default AWS-managed key is used."
  type        = string
  default     = null
}

variable "snapshot_retention_days" {
  description = "Number of days to retain automated snapshots"
  type        = number
  default     = 30
}

variable "snapshot_schedule_cron" {
  description = "Cron expression for DLM snapshot schedule (UTC)"
  type        = string
  default     = "cron(0 2 * * ? *)"
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
    Name        = "${var.application}-${var.environment}-data"
    Environment = var.environment
    Application = var.application
    Role        = "database"
    Backup      = "true"
    SnapshotPolicy = "daily"
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
  name               = "${var.application}-${var.environment}-dlm-lifecycle-role"
  assume_role_policy = data.aws_iam_policy_document.dlm_assume_role.json

  tags = {
    Environment = var.environment
    Application = var.application
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
      "ec2:EnableFastSnapshotRestores",
      "ec2:DescribeFastSnapshotRestores",
      "ec2:DisableFastSnapshotRestores"
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
  name   = "${var.application}-${var.environment}-dlm-lifecycle-policy"
  role   = aws_iam_role.dlm_lifecycle.id
  policy = data.aws_iam_policy_document.dlm_lifecycle.json
}

resource "aws_dlm_lifecycle_policy" "database_snapshots" {
  description        = "Automated EBS snapshot policy for ${var.application}-${var.environment} database volume"
  execution_role_arn = aws_iam_role.dlm_lifecycle.arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "Daily snapshots"

      create_rule {
        cron_expression = var.snapshot_schedule_cron
      }

      retain_rule {
        count = var.snapshot_retention_days
      }

      tags_to_add = {
        SnapshotCreator = "DLM"
        Application     = var.application
        Environment     = var.environment
      }

      copy_tags = true
    }

    target_tags = {
      Backup         = "true"
      SnapshotPolicy = "daily"
    }
  }

  tags = {
    Environment = var.environment
    Application = var.application
    ManagedBy   = "terraform"
  }
}

output "volume_id" {
  description = "ID of the EBS volume"
  value       = aws_ebs_volume.database.id
}

output "volume_arn" {
  description = "ARN of the EBS volume"
  value       = aws_ebs_volume.database.arn
}

output "dlm_policy_id" {
  description = "ID of the DLM lifecycle policy managing snapshots"
  value       = aws_dlm_lifecycle_policy.database_snapshots.id
}