provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/"
}

resource "aws_iam_policy" "jenkins_deploy_policy" {
  name        = "jenkins-deploy-policy"
  description = "Policy for jenkins-deploy user"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:PublishVersion",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListVersionsByFunction",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResources",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_deploy_attach" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.jenkins_deploy_policy.arn
}

resource "aws_iam_access_key" "jenkins_deploy_key" {
  user = aws_iam_user.jenkins_deploy.name
}