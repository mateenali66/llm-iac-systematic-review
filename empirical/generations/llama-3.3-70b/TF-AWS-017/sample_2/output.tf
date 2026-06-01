provider "aws" {
  region = "us-west-2"
}

resource "aws_ebs_volume" "database" {
  availability_zone = "us-west-2a"
  size              = 100
  type              = "gp3"
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn
}

resource "aws_kms_key" "ebs" {
  description             = "EBS volume encryption key"
  deletion_window_in_days = 10
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/ebs-key"
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_ebs_snapshot" "database" {
  volume_id = aws_ebs_volume.database.id
  tags = {
    Name = "database-snapshot"
  }
}

resource "aws_backup_vault" "database" {
  name = "database-backup-vault"
}

resource "aws_backup_plan" "database" {
  name = "database-backup-plan"

  rule {
    rule_name           = "daily"
    target_vault_name   = aws_backup_vault.database.name
    schedule            = "cron(0 12 * * ? *)"
    start_window        = 60
    completion_window = 180
  }
}

resource "aws_backup_selection" "database" {
  name         = "database-backup-selection"
  plan_id      = aws_backup_plan.database.id
  iam_role_arn = aws_iam_role.backup.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Backup"
    value = "true"
  }
}

resource "aws_iam_role" "backup" {
  name        = "database-backup-role"
  description = "IAM role for database backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "backup" {
  name        = "database-backup-policy"
  description = "IAM policy for database backup"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
          "ec2:CreateTags",
          "ebs:Describe*",
          "ebs:CreateSnapshot",
          "backup:StartBackupJob",
          "backup:UpdateRecoveryPoint",
          "backup:Describe*",
          "backup:Get*",
          "backup:List*",
        ]
        Effect = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = aws_iam_policy.backup.arn
}