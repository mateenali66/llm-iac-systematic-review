data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/webhook-handler.zip"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "webhook-handler-lambda-exec-role"

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

  tags = {
    Name = "webhook-handler-lambda-exec-role"
  }
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "webhook-handler-lambda-logging-policy"
  description = "IAM policy for logging from the webhook-handler Lambda function."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Effect   = "Allow"
      Resource = "${aws_cloudwatch_log_group.lambda_log_group.arn}:*"
      },
      {
        Action   = "logs:CreateLogGroup"
        Effect   = "Allow"
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
    }]
  })

  tags = {
    Name = "webhook-handler-lambda-logging-policy"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/webhook-handler"
  retention_in_days = 14

  tags = {
    Name = "webhook-handler-lambda-log-group"
  }
}

resource "aws_lambda_function" "webhook_handler" {
  function_name = "webhook-handler"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  publish       = true

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs_attach,
    aws_cloudwatch_log_group.lambda_log_group,
  ]

  tags = {
    Name = "webhook-handler"
  }
}