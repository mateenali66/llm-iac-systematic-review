terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}

variable "aws_region" {
  description = "AWS region to deploy to."
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}

provider "aws" {
  region = var.aws_region
}

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/webhook-handler.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "LambdaAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "webhook-handler-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray_write" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

data "aws_iam_policy_document" "kms_key_policy" {
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
    sid    = "AllowLambdaRoleUseOfKey"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.lambda.arn]
    }

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }
}

resource "aws_kms_key" "lambda_env" {
  description             = "KMS key for encrypting environment variables of Lambda 'webhook-handler'."
  enable_key_rotation     = true
  key_usage               = "ENCRYPT_DECRYPT"
  key_spec                = "SYMMETRIC_DEFAULT"
  policy                  = data.aws_iam_policy_document.kms_key_policy.json
  deletion_window_in_days = 30
  tags                    = var.tags
}

resource "aws_kms_alias" "lambda_env" {
  name          = "alias/webhook-handler-env"
  target_key_id = aws_kms_key.lambda_env.key_id
}

resource "aws_iam_role_policy" "kms_permissions" {
  name = "webhook-handler-kms-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowUseOfKmsKeyForEnv"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:Encrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = aws_kms_key.lambda_env.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/webhook-handler"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_lambda_function" "webhook_handler" {
  function_name = "webhook-handler"
  description   = "Processes incoming webhook events."
  role          = aws_iam_role.lambda.arn
  handler       = "handler.handler"
  runtime       = "python3.12"
  architectures = ["arm64"]

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10
  memory_size = 256
  publish     = true

  kms_key_arn = aws_kms_key.lambda_env.arn

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda
  ]

  tags = var.tags
}