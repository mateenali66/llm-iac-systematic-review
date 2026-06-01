resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/ci-cd/"
}

resource "aws_iam_access_key" "jenkins_deploy" {
  user = aws_iam_user.jenkins_deploy.name
}

resource "aws_iam_policy" "jenkins_deploy" {
  name        = "jenkins-deploy-lambda-cfn"
  description = "Least-privilege policy for Jenkins to deploy Lambda and manage CloudFormation stacks"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:GetTemplate"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_deploy" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.jenkins_deploy.arn
}