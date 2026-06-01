terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "lambda_role_arn" {
  type        = string
  description = "ARN of the Lambda execution role that requires read access to the database password secret."
}

variable "tags" {
  type        = map(string)
  description = "Common tags to apply to all resources."
  default     = {}
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_iam_policy_document" "kms_key_policy" {
  statement {
    sid = "EnableIAMUserPermissions"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid = "AllowSecretsManagerToUseKey"
    principals {
      type        = "Service"
      identifiers = ["secretsmanager.${data.aws_partition.current.dns_suffix}"]
    }
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_kms_key" "secrets" {
  description             = "CMK for encrypting Secrets Manager secrets (prod)"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  multi_region            = false
  policy                  = data.aws_iam_policy_document.kms_key_policy.json

  tags = merge(var.tags, {
    Name        = "prod-secretsmanager-cmk"
    Environment = "prod"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/prod/secretsmanager"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "prod/database/password"
  description             = "Production database password used by the Lambda function."
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 30

  tags = merge(var.tags, {
    Name        = "prod/database/password"
    Environment = "prod"
  })

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "secret_access" {
  statement {
    sid = "AllowLambdaReadSecret"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [var.lambda_role_arn]
    }

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.db_password.arn,
      "${aws_secretsmanager_secret.db_password.arn}:*"
    ]
  }
}

resource "aws_secretsmanager_secret_policy" "db_password" {
  secret_arn          = aws_secretsmanager_secret.db_password.arn
  policy              = data.aws_iam_policy_document.secret_access.json
  block_public_policy = true
}