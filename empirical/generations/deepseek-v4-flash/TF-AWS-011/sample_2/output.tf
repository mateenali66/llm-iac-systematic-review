resource "aws_lambda_function" "webhook_handler" {
  function_name = "webhook-handler"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "webhook-handler"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "./lambda"
  output_path = "./lambda_function_payload.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "webhook-handler-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "webhook-handler-lambda-exec-role"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray_write" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/webhook-handler"
  retention_in_days = 14

  tags = {
    Name        = "webhook-handler-logs"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}