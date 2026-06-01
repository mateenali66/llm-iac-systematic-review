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
  description = "Name of the IAM user for Jenkins CI/CD"
  type        = string
  default     = "jenkins-deploy"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    ManagedBy   = "Terraform"
    Purpose     = "CI/CD"
    Application = "Jenkins"
    Environment = "production"
  }
}

variable "lambda_function_arns" {
  description = "List of Lambda function ARNs the user is allowed to deploy/update. Use specific ARNs for least privilege."
  type        = list(string)
  default     = ["*"]
}

variable "cloudformation_stack_arns" {
  description = "List of CloudFormation stack ARNs the user is allowed to manage. Use specific ARNs for least privilege."
  type        = list(string)
  default     = ["*"]
}

variable "artifact_bucket_arns" {
  description = "List of S3 bucket ARNs storing deployment artifacts (Lambda zips, CFN templates)."
  type        = list(string)
  default     = []
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

resource "aws_iam_user" "jenkins_deploy" {
  name          = var.user_name
  path          = "/ci-cd/"
  force_destroy = false

  tags = merge(var.tags, {
    Name = var.user_name
  })
}

# Lambda deployment policy - scoped to update/deploy operations
data "aws_iam_policy_document" "lambda_deploy" {
  statement {
    sid    = "LambdaReadOnly"
    effect = "Allow"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:GetFunctionCodeSigningConfig",
      "lambda:GetAlias",
      "lambda:GetPolicy",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:ListTags",
      "lambda:ListFunctions",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LambdaDeploy"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:DeleteAlias",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
    ]
    resources = var.lambda_function_arns
  }
}

resource "aws_iam_policy" "lambda_deploy" {
  name        = "${var.user_name}-lambda-deploy"
  description = "Allows Jenkins to deploy and update AWS Lambda functions"
  policy      = data.aws_iam_policy_document.lambda_deploy.json
  tags        = var.tags
}

# CloudFormation deployment policy
data "aws_iam_policy_document" "cloudformation_deploy" {
  statement {
    sid    = "CloudFormationReadOnly"
    effect = "Allow"
    actions = [
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStackResource",
      "cloudformation:DescribeStackResources",
      "cloudformation:DescribeChangeSet",
      "cloudformation:GetTemplate",
      "cloudformation:GetTemplateSummary",
      "cloudformation:ListStacks",
      "cloudformation:ListStackResources",
      "cloudformation:ListChangeSets",
      "cloudformation:ValidateTemplate",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CloudFormationDeploy"
    effect = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:DeleteStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:SetStackPolicy",
      "cloudformation:UpdateTerminationProtection",
      "cloudformation:TagResource",
      "cloudformation:UntagResource",
    ]
    resources = var.cloudformation_stack_arns
  }
}

resource "aws_iam_policy" "cloudformation_deploy" {
  name        = "${var.user_name}-cloudformation-deploy"
  description = "Allows Jenkins to manage CloudFormation stacks"
  policy      = data.aws_iam_policy_document.cloudformation_deploy.json
  tags        = var.tags
}

# IAM PassRole - required for CloudFormation/Lambda to assume execution roles
data "aws_iam_policy_document" "pass_role" {
  statement {
    sid       = "PassRoleToLambdaAndCFN"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "lambda.am