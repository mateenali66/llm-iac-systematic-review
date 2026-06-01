terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "user_name" {
  description = "Name of the IAM user for the Jenkins CI/CD pipeline"
  type        = string
  default     = "jenkins-deploy"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Purpose     = "CI/CD Pipeline"
    Owner       = "DevOps"
    Environment = "production"
  }
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

resource "aws_iam_user" "jenkins_deploy" {
  name          = var.user_name
  path          = "/ci-cd/"
  force_destroy = false

  tags = merge(var.tags, {
    Name = var.user_name
  })
}

data "aws_iam_policy_document" "lambda_deploy" {
  statement {
    sid    = "LambdaDeployPermissions"
    effect = "Allow"
    actions = [
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
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
      "lambda:GetFunctionConcurrency"
    ]
    resources = [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*",
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:layer:*"
    ]
  }

  statement {
    sid    = "LambdaListAll"
    effect = "Allow"
    actions = [
      "lambda:ListFunctions",
      "lambda:ListLayers",
      "lambda:GetAccountSettings"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudFormationDeployPermissions"
    effect = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStackResource",
      "cloudformation:DescribeStackResources",
      "cloudformation:GetTemplate",
      "cloudformation:GetTemplateSummary",
      "cloudformation:ListStackResources",
      "cloudformation:ValidateTemplate",
      "cloudformation:CreateChangeSet",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:ListChangeSets",
      "cloudformation:SetStackPolicy",
      "cloudformation:TagResource",
      "cloudformation:UntagResource"
    ]
    resources = [
      "arn:aws:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:stack/*/*",
      "arn:aws:cloudformation:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:changeSet/*/*"
    ]
  }

  statement {
    sid    = "CloudFormationListAll"
    effect = "Allow"
    actions = [
      "cloudformation:ListStacks",
      "cloudformation:ValidateTemplate",
      "cloudformation:DescribeAccountLimits"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LambdaArtifactsS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::*-lambda-artifacts-*",
      "arn:aws:s3:::*-lambda-artifacts-*/*",
      "arn:aws:s3:::*-cfn-templates-*",
      "arn:aws:s3:::*-cfn-templates-*/*"
    ]
  }

  statement {
    sid    = "PassRoleToLambdaAndCFN"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/lambda-*",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cfn-*"
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "lambda.amazonaws.com",
        "cloudformation.amazonaws.com"
      ]
    }
  }

  statement {
    sid    = "Cloud