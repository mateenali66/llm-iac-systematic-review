data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "log_encryption" {
  description             = "KMS key for encrypting the /aws/app/prod CloudWatch log group"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.log_encryption_policy.json

  tags = {
    Name        = "cloudwatch-log-encryption-key-prod"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "log_encryption_policy" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsEncryption"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"] # The resource is the key itself, so "*" is appropriate here.
  }
}

resource "aws_kms_alias" "log_encryption_alias" {
  name          = "alias/aws/app/prod-logs"
  target_key_id = aws_kms_key.log_encryption.key_id
}

resource "aws_cloudwatch_log_group" "application_prod" {
  name              = "/aws/app/prod"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.log_encryption.arn

  tags = {
    Name        = "/aws/app/prod"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}