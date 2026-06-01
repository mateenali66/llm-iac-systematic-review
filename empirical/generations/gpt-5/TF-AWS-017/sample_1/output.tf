terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "db_instance_id" {
  description = "EC2 instance ID for the database host to attach the EBS volume to"
  type        = string
}

variable "application_name" {
  description = "Application name for tagging"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name (e.g., prod, staging)"
  type        = string
  default     = "prod"
}

variable "device_name" {
  description = "Linux device name for attachment"
  type        = string
  default     = "/dev/xvdb"
}

variable "ebs_iops" {
  description = "Provisioned IOPS for gp3 volume"
  type        = number
  default     = 6000
}

variable "ebs_throughput" {
  description = "Throughput (MiB/s) for gp3 volume"
  type        = number
  default     = 250
}

variable "backup_schedule_cron" {
  description = "AWS Backup cron expression for daily backups"
  type        = string
  default     = "cron(0 5 * * ? *)"
}

variable "backup_cold_storage_after_days" {
  description = "Days after creation to transition backups to cold storage"
  type        = number
  default     = 30
}

variable "backup_delete_after_days" {
  description = "Days after creation to delete backups"
  type        = number
  default     = 35
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_instance" "db" {
  instance_id = var.db_instance_id
}

resource "aws_iam_role" "backup" {
  name               = "backup-service-role"
  assume_role_policy = data.aws_iam_policy_document.backup_trust.json
  tags = {
    Name        = "backup-service-role"
    Application = var.application_name
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "backup_trust" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "backup_policy" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore_policy" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

data "aws_iam_policy_document" "ebs_kms_policy" {
  statement {
    sid    = "AllowRootAccountAdmin"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowEC2AndBackupServiceUse"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com", "backup.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "ec2.${data.aws_region.current.name}.amazonaws.com",
        "backup.${data.aws_region.current.name}.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "AllowBackupRoleUse"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.backup.arn]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "ebs" {
  description             = "KMS key for encrypting EBS volumes and snapshots for ${var.application_name}-${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.ebs_kms_policy.json
  tags = {
    Name        = "kms-ebs-${var.application_name}-${var.environment}"
    Application = var.application_name
    Environment = var.environment
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/ebs-${var.application_name}-${var.environment}"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_ebs_volume" "db_data" {
  availability_zone = data.aws_instance.db.availability_zone
  size              = 100
  type              = "gp3"
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn
  iops              = var.ebs_iops
  throughput        = var.ebs_throughput
  multi_attach_enabled = false

  tags = {
    Name        = "ebs-${var.application_name}-${var.environment}-db-data"
    Application = var.application_name
    Environment = var.environment
    backup      = "true"
  }
}

resource "aws_volume_attachment" "db_data_attach" {
  device_name  = var.device_name
  volume_id    = aws_ebs_volume.db_data.id
  instance_id  = var.db_instance_id
  force_detach = false
  stop_instance_before_detaching = true
}

data "aws_iam_policy_document" "backup_vault_kms_policy" {
  statement {
    sid    = "AllowRootAccountAdmin"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowBackupServiceUseOfVaultKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["backup.${data.aws_region.current.name}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "backup_vault" {
  description             = "KMS key for AWS Backup vault for ${var.application_name}-${var.environment}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.backup_vault_kms_policy.json
  tags = {
    Name        = "kms-backup-vault-${var.application_name}-${var.environment}"
    Application = var.application_name
    Environment = var.environment
  }
}

resource "aws_kms_alias" "backup_vault" {
  name          = "alias/backup-vault-${var.application_name}-${var.environment}"
  target_key_id = aws_kms_key.backup_vault.key_id
}

resource "aws_backup_vault" "primary" {
  name        = "backup-vault-${var.application_name}-${var.environment}"
  kms_key_arn = aws_kms_key.backup_vault.arn
  tags = {
    Name        = "backup-vault-${var.application_name}-${var.environment}"
    Application = var.application_name
    Environment = var.environment
  }
}

resource "aws_backup_plan" "daily" {
  name = "backup-plan-${var.application_name}-${var.environment}"

  rule {
    rule_name         = "daily-ebs-snapshots"
    target_vault_name = aws_backup_vault.primary.name
    schedule          = var.backup_schedule_cron

    lifecycle {
      cold_storage_after = var.backup_cold_storage_after_days
      delete_after       = var.backup_delete_after_days
    }

    recovery_point_tags = {
      Application = var.application_name
      Environment = var.environment
    }
  }

  tags = {
    Name        = "backup-plan-${var.application_name}-${var.environment}"
    Application = var.application_name
    Environment = var.environment
  }
}

resource "aws_backup_selection" "tagged_resources" {
  name         = "select-tagged-backup-${var.application_name}-${var.environment}"
  plan_id      = aws_backup_plan.daily.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "backup"
    value = "true"
  }
}