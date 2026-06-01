terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources into."
  default     = "us-east-1"
}

variable "prod_db_password" {
  description = "Production database password to store in Secrets Manager."
  type        = string
  sensitive   = true
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
  default = {
    Environment = "prod"
    ManagedBy   = "terraform"
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "secrets" {
  description             = "KMS CMK for encrypting Secrets Manager secrets (prod)"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid      = "EnableRootPermissions",
        Effect   = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      {
        Sid      = "AllowSecretsManagerUseOfKey",
        Effect   = "Allow",
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        },
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*"
        ],
        Resource  = "*",
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "secretsmanager.${data.aws_region.current.name}.amazonaws.com",
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "prod-secrets-cmk"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/prod/secretsmgr"
  target_key_id = aws_kms_key.secrets.key_id
}

resource "aws_secretsmanager_secret" "prod_db_password" {
  name                    = "prod/database/password"
  description             = "Production database password used by Lambda functions."
  kms_key_id              = aws_kms_key.secrets.arn
  recovery_window_in_days = 30
  block_public_policy     = true

  tags = merge(var.tags, {
    Name = "prod-database-password"
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_secretsmanager_secret_version" "prod_db_password" {
  secret_id     = aws_secretsmanager_secret.prod_db_password.id
  secret_string = var.prod_db_password
}

resource "aws_iam_role" "lambda_db_password_reader" {
  name = "lambda-prod-db-password-reader"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda_read_secret" {
  name = "allow-read-prod-db-password-secret"
  role = aws_iam_role.lambda_db_password_reader.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "ReadSecretValue",
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds"
        ],
        Resource = [
          aws_secretsmanager_secret.prod_db_password.arn,
          "${aws_secretsmanager_secret.prod_db_password.arn}*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logging" {
  role       = aws_iam_role.lambda_db_password_reader.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}