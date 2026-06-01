resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/ci-cd/"
  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
    Purpose     = "jenkins-lambda-cfn-deploy"
  }
}

resource "aws_iam_policy" "jenkins_deploy_policy" {
  name        = "jenkins-deploy-lambda-cfn-policy"
  description = "Least-privilege policy for Jenkins to deploy Lambda functions and manage CloudFormation stacks"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaDeploy"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListTags",
          "lambda:TagResource",
          "lambda:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudFormationDeploy"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResources",
          "cloudformation:GetTemplate"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRoleForLambda"
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

resource "aws_iam_user_policy_attachment" "jenkins_deploy_attach" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.jenkins_deploy_policy.arn
}