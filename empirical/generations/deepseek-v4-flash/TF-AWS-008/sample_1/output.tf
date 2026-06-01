resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/system/"
}

resource "aws_iam_access_key" "jenkins_deploy" {
  user = aws_iam_user.jenkins_deploy.name
}

resource "aws_iam_user_policy" "jenkins_deploy" {
  name = "jenkins-deploy-policy"
  user = aws_iam_user.jenkins_deploy.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "LambdaDeploy"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
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
          "lambda:GetFunctionConfiguration",
          "lambda:ListVersionsByFunction",
          "lambda:GetLayerVersion",
          "lambda:ListLayerVersions",
          "lambda:PublishLayerVersion",
          "lambda:DeleteLayerVersion",
          "lambda:GetLayerVersionPolicy",
          "lambda:AddLayerVersionPermission",
          "lambda:RemoveLayerVersionPermission",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags"
        ]
        Resource = "*"
      },
      {
        Sid = "CloudFormationDeploy"
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
          "cloudformation:GetTemplateSummary",
          "cloudformation:ContinueUpdateRollback",
          "cloudformation:CancelUpdateStack",
          "cloudformation:SignalResource",
          "cloudformation:TagResource",
          "cloudformation:UntagResource",
          "cloudformation:ListExports",
          "cloudformation:ListImports"
        ]
        Resource = "*"
      },
      {
        Sid = "PassRoleForLambda"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "arn:aws:iam::*:role/*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
      {
        Sid = "S3GetObjectForLambdaDeployment"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "arn:aws:s3:::*-deploy-bucket/*"
      },
      {
        Sid = "CloudWatchLogsForLambda"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/aws/lambda/*"
      }
    ]
  })
}