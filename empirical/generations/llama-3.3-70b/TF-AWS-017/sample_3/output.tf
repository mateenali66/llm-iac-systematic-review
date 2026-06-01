resource "aws_ebs_volume" "database" {
  availability_zone = "us-west-2a"
  size              = 100

  tags = {
    Name        = "database-ebs-volume"
    Environment = "production"
  }
}

resource "aws_ebs_snapshot" "database" {
  volume_id = aws_ebs_volume.database.id

  tags = {
    Name        = "database-ebs-snapshot"
    Environment = "production"
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
    schedule             = "cron(0 12 * * ? *)"
    start_window         = 60
    completion_window    = 180
    lifecycle {
      delete_after = 30
    }
  }
}

resource "aws_backup_selection" "database" {
  name         = "database-backup-selection"
  plan_id      = aws_backup_plan.database.id
  iam_role_arn = aws_iam_role.database.arn

  selection_tag {
    type  = "STRINGEQUALS"
    key   = "Environment"
    value = "production"
  }
}

resource "aws_iam_role" "database" {
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
      }
    ]
  })
}

resource "aws_iam_policy" "database" {
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
          "ebs:DeleteSnapshot",
          "ebs:DescribeSnapshotAttribute",
          "ebs:ModifySnapshotAttribute",
        ]
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "database" {
  role       = aws_iam_role.database.name
  policy_arn = aws_iam_policy.database.arn
}