terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "webhook-handler"
}

variable "lambda_source_dir" {
  description = "Directory containing the Lambda source code"
  type        = string
  default     = "./lambda"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge(
    {
      Name        = var.function_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Application = "webhook-handler"
    },
    var.tags
  )
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.lambda_source_dir
  output_path = "${path.module}/build/${var.function_name}.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name                 = "${var.function_name}-exec-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  max_session_duration = 3600

  tags = local.common_tags
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.lambda_logs.arn}:*"
    ]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "${var.function_name}-logging-policy"
  description = "IAM policy for logging from ${var.function_name} Lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_logging" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = local.common_tags
}

resource "aws_lambda_function" "webhook_handler" {
  function_name    = var.function_name
  description      = "Processes incoming webhook events"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  reserved_concurrent_executions = -1

  ephemeral_storage {
    size = 512
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      ENVIRONMENT = var.environment
      LOG_LEVEL   = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logging,
    aws_cloudwatch_log_group.lambda_logs
  ]

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSXRayDaemonWriteAccess"
}

resource "aws_lambda_function_url" "webhook_url" {
  function_name      = aws_lambda_function.webhook_handler.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_credentials = false
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["content-type", "x-webhook-signature"]
    expose_headers    = []
    max_age           = 86400
  }
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.webhook_handler.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.webhook_handler.function_name
}

output "lambda_function_url" {
  description = "Function URL endpoint"
  value       = aws_lambda_function_url.webhook_url.function_url
}

output "