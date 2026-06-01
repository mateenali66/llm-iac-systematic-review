provider "aws" {
  region = "us-west-2"
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "lambda_exec" {
  name        = "webhook-handler-exec"
  description = "Execution role for webhook handler Lambda function"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid      = ""
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name        = "webhook-handler-policy"
  description = "Policy for webhook handler Lambda function"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"
        Effect    = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_lambda_function" "webhook_handler" {
  filename      = "./lambda/handler.py.zip"
  function_name = "webhook-handler"
  handler       = "handler.lambda_handler"
  runtime       = "python3.12"
  role          = aws_iam_role.lambda_exec.arn
}

resource "aws_lambda_permission" "webhook_handler_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.webhook_handler_api.execution_arn}/*/*"
}

resource "aws_api_gateway_rest_api" "webhook_handler_api" {
  name        = "webhook-handler-api"
  description = "API for webhook handler"
}

resource "aws_api_gateway_resource" "webhook_handler_resource" {
  rest_api_id = aws_api_gateway_rest_api.webhook_handler_api.id
  parent_id   = aws_api_gateway_rest_api.webhook_handler_api.root_resource_id
  path_part   = "webhook"
}

resource "aws_api_gateway_method" "webhook_handler_method" {
  rest_api_id = aws_api_gateway_rest_api.webhook_handler_api.id
  resource_id = aws_api_gateway_resource.webhook_handler_resource.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "webhook_handler_integration" {
  rest_api_id = aws_api_gateway_rest_api.webhook_handler_api.id
  resource_id = aws_api_gateway_resource.webhook_handler_resource.id
  http_method = aws_api_gateway_method.webhook_handler_method.http_method
  integration_http_method = "POST"
  type        = "LAMBDA"
  uri         = "arn:aws:apigateway:${aws_api_gateway_rest_api.webhook_handler_api.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.webhook_handler.arn}/invocations"
}

resource "aws_api_gateway_deployment" "webhook_handler_deployment" {
  depends_on  = [aws_api_gateway_integration.webhook_handler_integration]
  rest_api_id = aws_api_gateway_rest_api.webhook_handler_api.id
  stage_name  = "prod"
}