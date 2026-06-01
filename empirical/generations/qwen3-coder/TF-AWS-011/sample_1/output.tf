resource "aws_lambda_function" "webhook_handler" {
  function_name = "webhook-handler"
  runtime       = "python3.12"
  handler       = "handler.lambda_handler"
  
  filename         = "./lambda/handler.py"
  source_code_hash = filebase64sha256("./lambda/handler.py")
  
  role = aws_iam_role.lambda_execution_role.arn
  
  timeout     = 30
  memory_size = 128
  
  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }
}

resource "aws_iam_role" "lambda_execution_role" {
  name = "webhook-handler-execution-role"
  
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
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}