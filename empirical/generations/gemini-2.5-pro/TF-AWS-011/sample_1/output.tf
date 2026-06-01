data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda_handler.zip"
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "webhook-handler-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "webhook-handler-lambda-exec-role"
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/webhook-handler"
  retention_in_days = 14

  tags = {
    Name = "webhook-handler-log-group"
  }
}

resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "webhook-handler-lambda-logging-policy"
  description = "IAM policy for Lambda function to write logs to CloudWatch"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "${aws_cloudwatch_log_group.lambda_log_group.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logging_attachment" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

resource "aws_lambda_function" "webhook_handler" {
  function_name    = "webhook-handler"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_logging_attachment,
    aws_cloudwatch_log_group.lambda_log_group
  ]

  tags = {
    Name = "webhook-handler"
  }
}