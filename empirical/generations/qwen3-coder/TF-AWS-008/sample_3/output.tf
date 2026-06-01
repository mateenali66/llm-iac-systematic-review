resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/cicd/"
}

resource "aws_iam_user_policy" "jenkins_deploy_policy" {
  name = "jenkins-deploy-policy"
  user = aws_iam_user.jenkins_deploy.name

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
          "lambda:ListFunctions",
          "lambda:DeleteFunction",
          "lambda:AddPermission",
          "lambda:RemovePermission"
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
          "cloudformation:ValidateTemplate",
          "cloudformation:GetTemplate",
          "cloudformation:DeleteStack",
          "cloudformation:CreateChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:DescribeChangeSet"
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
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::*/*"
      }
    ]
  })
}

resource "aws_iam_access_key" "jenkins_deploy_key" {
  user = aws_iam_user.jenkins_deploy.name
}