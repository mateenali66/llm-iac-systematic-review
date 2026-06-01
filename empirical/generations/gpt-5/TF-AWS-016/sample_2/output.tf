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
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "database_password" {
  description = "Production database password to store in AWS Secrets Manager."
  type        = string
  sensitive   = true
}

variable "allowed_principal_arns" {
  description = "List of IAM principal ARNs (e.g., Lambda execution roles) allowed to read the secret."
  type        = list(string)
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  common_tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
    Name        = "prod-database-password"
  }
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowSecretsManagerUse"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["secretsmanager.amazonaws.com"]
    }
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
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
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "secrets" {
  description         = "KMS key for encrypting production Secrets Manager secrets"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms.json
  tags                = local.common_tags
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/secretsmgr-prod"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "prod/database/password"
  description             = "Production database password used by Lambda functions"
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 30
  tags                    = local.common_tags
}

data "aws_iam_policy_document" "secret" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["secretsmanager:*"]
    resources = [
      aws_secretsmanager_secret.db_password.arn,
      "${aws_secretsmanager_secret.db_password.arn}*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "AllowLambdaRead"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_principal_arns
    }

    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret"
    ]

    resources = [
      aws_secretsmanager_secret.db_password.arn,
      "${aws_secretsmanager_secret.db_password.arn}*"
    ]
  }
}

resource "aws_secretsmanager_secret_policy" "db_password" {
  secret_arn         = aws_secretsmanager_secret.db_password.arn
  policy             = data.aws_iam_policy_document.secret.json
  block_public_policy = true
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.database_password
}