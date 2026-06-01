resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/system/"

  tags = {
    Name        = "jenkins-deploy"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_access_key" "jenkins_deploy" {
  user = aws_iam_user.jenkins_deploy.name
}

resource "aws_iam_user_policy" "jenkins_deploy_lambda" {
  name = "jenkins-deploy-lambda-policy"
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
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:InvokeFunction",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:DeleteFunction",
          "lambda:DeleteAlias",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:GetLayerVersion",
          "lambda:ListLayerVersions",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags"
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
          "cloudformation:GetTemplate",
          "cloudformation:ValidateTemplate",
          "cloudformation:ListStacks",
          "cloudformation:ListStackResources",
          "cloudformation:CreateChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:ListChangeSets",
          "cloudformation:GetStackPolicy",
          "cloudformation:SetStackPolicy",
          "cloudformation:TagResource",
          "cloudformation:UntagResource",
          "cloudformation:ListTags"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole",
          "iam:GetRole"
        ]
        Resource = "arn:aws:iam::*:role/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::jenkins-deploy-artifacts",
          "arn:aws:s3:::jenkins-deploy-artifacts/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy" "jenkins_deploy_cloudwatch" {
  name = "jenkins-deploy-cloudwatch-policy"
  user = aws_iam_user.jenkins_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      }
    ]
  })
}