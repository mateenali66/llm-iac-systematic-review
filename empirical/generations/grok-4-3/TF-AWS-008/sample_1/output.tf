resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/ci-cd/"
}

resource "aws_iam_policy" "jenkins_deploy_policy" {
  name        = "jenkins-deploy-lambda-cfn-policy"
  description = "Least-privilege policy for Jenkins to deploy Lambda functions and manage CloudFormation stacks"
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
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
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
          "cloudformation:ListStacks",
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
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*-lambda-deployments",
          "arn:aws:s3:::*-lambda-deployments/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_deploy_attach" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.jenkins_deploy_policy.arn
}