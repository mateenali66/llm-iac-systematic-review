variable "db_instance_id" {
  description = "The ID of the database EC2 instance to attach the EBS volume to."
  type        = string
}

variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
  default     = "app"
}

variable "device_name" {
  description = "The device name to expose to the instance (e.g., /dev/sdf)."
  type        = string
  default     = "/dev/sdf"
}

variable "volume_size" {
  description = "Size of the EBS volume in GiB. Must be 100 for this use case."
  type        = number
  default     = 100

  validation {
    condition     = var.volume_size == 100
    error_message = "volume_size must be exactly 100 GiB as required."
  }
}

variable "volume_iops" {
  description = "Provisioned IOPS for the gp3 volume."
  type        = number
  default     = 3000
}

variable "volume_throughput" {
  description = "Provisioned throughput (MiB/s) for the gp3 volume."
  type        = number
  default     = 125
}

variable "backup_retention_days" {
  description = "Number of days to retain EBS snapshots."
  type        = number
  default     = 35

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 3650
    error_message = "backup_retention_days must be between 7 and 3650."
  }
}

variable "backup_schedule_cron" {
  description = "Cron expression for AWS Backup schedule."
  type        = string
  default     = "cron(0 5 * * ? *)"
}

variable "tags" {
  description = "Common tags to apply to resources."
  type        = map(string)
  default     = {}
}

data "aws_instance" "db" {
  instance_id = var.db_instance_id
}

data "aws_caller_identity" "current" {}

resource "aws_kms_key" "ebs" {
  description         = "KMS key for encrypting EBS volumes for ${var.name_prefix}"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
  tags = merge({
    Name = "${var.name_prefix}-ebs-kms"
  }, var.tags)
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.name_prefix}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_kms_key" "backup" {
  description         = "KMS key for AWS Backup vault for ${var.name_prefix}"
  enable_key_rotation = true
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
  tags = merge({
    Name = "${var.name_prefix}-backup-kms"
  }, var.tags)
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.name_prefix}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

resource "aws_backup_vault" "db" {
  name        = "${var.name_prefix}-db-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn
  tags = merge({
    Name = "${var.name_prefix}-db-backup-vault"
  }, var.tags)
}

resource "aws_backup_plan" "db_daily" {
  name = "${var.name_prefix}-db-ebs-daily"

  rule {
    rule_name         = "daily-ebs-snapshots"
    target_vault_name = aws_backup_vault.db.name
    schedule          = var.backup_schedule_cron

    lifecycle {
      delete_after = var.backup_retention_days
    }

    start_window     = 60
    completion_window = 120
  }

  tags = merge({
    Name = "${var.name_prefix}-db-ebs-daily-plan"
  }, var.tags)
}

resource "aws_iam_role" "aws_backup" {
  name = "${var.name_prefix}-aws-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "backup.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
  tags = merge({
    Name = "${var.name_prefix}-aws-backup-role"
  }, var.tags)
}

resource "aws_iam_role_policy_attachment" "aws_backup_attach" {
  role       = aws_iam_role.aws_backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "db_ebs" {
  name         = "${var.name_prefix}-db-ebs-selection"
  plan_id      = aws_backup_plan.db_daily.id
  iam_role_arn = aws_iam_role.aws_backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "daily"
  }
}

resource "aws_ebs_volume" "db_data" {
  availability_zone = data.aws_instance.db.availability_zone
  size              = var.volume_size
  type              = "gp3"
  iops              = var.volume_iops
  throughput        = var.volume_throughput
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn

  tags = merge({
    Name   = "${var.name_prefix}-db-data"
    Backup = "daily"
  }, var.tags)
}

resource "aws_volume_attachment" "db_data" {
  device_name = var.device_name
  volume_id   = aws_ebs_volume.db_data.id
  instance_id = data.aws_instance.db.id
}