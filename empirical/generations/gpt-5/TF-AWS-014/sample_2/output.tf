terraform {
  required_version = ">= 1.4.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "kms_cw_logs" {
  statement {
    sid     = "AllowRootAccountFullAccess"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsUseOfTheKey"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/app/prod*"
      ]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_kms_key" "cloudwatch_logs" {
  description         = "KMS key for encrypting CloudWatch Logs for production application"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms_cw_logs.json

  tags = {
    Name        = "cloudwatch-logs-app-prod"
    Environment = "prod"
    Application = "app"
    ManagedBy   = "Terraform"
  }
}

resource "aws_kms_alias" "cloudwatch_logs" {
  name          = "alias/cloudwatch-logs-app-prod"
  target_key_id = aws_kms_key.cloudwatch_logs.key_id
}

resource "aws_cloudwatch_log_group" "app_prod" {
  name              = "/aws/app/prod"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.cloudwatch_logs.arn
  skip_destroy      = true

  tags = {
    Name        = "/aws/app/prod"
    Environment = "prod"
    Application = "app"
    ManagedBy   = "Terraform"
  }
}