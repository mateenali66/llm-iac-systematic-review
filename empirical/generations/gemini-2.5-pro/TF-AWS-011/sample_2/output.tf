locals {
  function_name = "webhook-handler"
  handler_path  = "handler.lambda_handler"
  source_path   = "${path.module}/lambda"
  output_path   = "${path.module}/webhook-handler.zip"
  runtime       = "python3.12"
  tags = {
    ManagedBy   = "Terraform"
    Project     = "WebhookProcessor"
    Environment = "Production"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = local.source_path
  output_path = local.output_path
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "${local.function_name}-exec-role"
  tags = local.tags

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_lambda_function" "webhook_handler" {
  function_name    = local.function_name
  handler          = local.handler_path
  runtime          = local.runtime
  role             = aws_iam_role.lambda_exec_role.arn
  architectures    = ["arm64"]
  memory_size      = 256
  timeout          = 30
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  tags             = local.tags

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  logging_config {
    log_format = "Text"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}