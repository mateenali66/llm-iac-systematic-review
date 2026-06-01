terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  user_name = "jenkins-deploy"

  common_tags = {
    Name        = "jenkins-deploy"
    ManagedBy   = "Terraform"
    Purpose     = "CI/CD Pipeline"
    Environment = "production"
  }
}

resource "aws_iam_user" "jenkins_deploy" {
  name          = local.user_name
  path          = "/ci-cd/"
  force_destroy = false

  tags = local.common_tags
}

resource "aws_iam_user_policy_attachment" "lambda_deploy" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.lambda_deploy.arn
}

resource "aws_iam_user_policy_attachment" "cloudformation_deploy" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.cloudformation_deploy.arn
}

resource "aws_iam_policy" "lambda_deploy" {
  name        = "${local.user_name}-lambda-deploy"
  path        = "/ci-cd/"
  description = "Permissions for Jenkins to deploy and manage AWS Lambda functions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaDeployPermissions"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:DeleteFunction",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:ListFunctions",
          "lambda:ListVersionsByFunction",
          "lambda:PublishVersion",
          "lambda:CreateAlias",
          "lambda:UpdateAlias",
          "lambda:DeleteAlias",
          "lambda:GetAlias",
          "lambda:ListAliases",
          "lambda:TagResource",
          "lambda:UntagResource",
          "lambda:ListTags",
          "lambda:AddPermission",
          "lambda:RemovePermission",
          "lambda:GetPolicy",
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:*:*:function:*"
      },
      {
        Sid    = "LambdaListPermissions"
        Effect = "Allow"
        Action = [
          "lambda:ListFunctions",
          "lambda:ListEventSourceMappings",
          "lambda:GetAccountSettings"
        ]
        Resource = "*"
      },
      {
        Sid    = "PassRoleToLambda"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "arn:aws:iam::*:role/*lambda*"
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "lambda.amazonaws.com"
          }
        }
      },
      {
        Sid    = "LambdaArtifactStorage"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::*-lambda-artifacts",
          "arn:aws:s3:::*-lambda-artifacts/*",
          "arn:aws:s3:::*-deployment-artifacts",
          "arn:aws:s3:::*-deployment-artifacts/*"
        ]
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "cloudformation_deploy" {
  name        = "${local.user_name}-cloudformation-deploy"
  path        = "/ci-cd/"
  description = "Permissions for Jenkins to deploy and update CloudFormation stacks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CloudFormationStackManagement"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateStack",
          "cloudformation:UpdateStack",
          "cloudformation:DeleteStack",
          "cloudformation:DescribeStacks",
          "cloudformation:DescribeStackEvents",
          "cloudformation:DescribeStackResource",
          "cloudformation:DescribeStackResources",
          "cloudformation:GetTemplate",
          "cloudformation:GetTemplateSummary",
          "cloudformation:ListStacks",
          "cloudformation:ListStackResources",
          "cloudformation:CreateChangeSet",
          "cloudformation:DescribeChangeSet",
          "cloudformation:ExecuteChangeSet",
          "cloudformation:DeleteChangeSet",
          "cloudformation:ListChangeSets",
          "cloudformation:ValidateTemplate",
          "cloudformation:SetStackPolicy",
          "cloudformation:GetStackPolicy",
          "cloudformation:TagResource",
          "cloudformation:UntagResource",
          "cloudformation:ContinueUpdateRollback",
          "cloudformation:CancelUpdateStack"
        ]
        Resource = "arn:aws:cloudformation:*:*:stack/*/*"
      },
      {
        Sid    = "CloudFormationReadOnly"
        Effect = "Allow"
        Action = [
          "cloudformation:ValidateTemplate",
          "cloudformation:EstimateTemplateCost",
          "cloudformation:DescribeAccountLimits"
        ]