locals {
  common_tags = {
    ManagedBy = "Terraform"
    Owner     = "CI/CD"
    Name      = "jenkins-deploy"
  }
}

data "aws_iam_policy_document" "jenkins_deploy_boundary_doc" {
  statement {
    sid     = "CloudFormationCore"
    effect  = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStackResources",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ListChangeSets",
      "cloudformation:CreateChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:GetTemplate",
      "cloudformation:GetTemplateSummary",
      "cloudformation:ValidateTemplate",
      "cloudformation:CancelUpdateStack",
      "cloudformation:ListStacks",
      "cloudformation:ListStackResources",
      "cloudformation:ListExports",
      "cloudformation:ListImports",
      "cloudformation:TagResource",
      "cloudformation:UntagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "LambdaDeployment"
    effect  = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:DeleteAlias",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:ListFunctions",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "IamPassRoleRestrictedToServices"
    effect  = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["arn:aws:iam::*:role/*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com", "cloudformation.amazonaws.com"]
    }
  }

  statement {
    sid     = "StsReadOnly"
    effect  = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "sts:GetSessionToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "jenkins_deploy_boundary" {
  name        = "jenkins-deploy-permissions-boundary"
  path        = "/permissions-boundary/"
  description = "Permissions boundary for jenkins-deploy CI/CD user to deploy Lambda and manage CloudFormation"
  policy      = data.aws_iam_policy_document.jenkins_deploy_boundary_doc.json
  tags        = local.common_tags
}

resource "aws_iam_user" "jenkins_deploy" {
  name                 = "jenkins-deploy"
  path                 = "/svc/"
  permissions_boundary = aws_iam_policy.jenkins_deploy_boundary.arn
  tags                 = local.common_tags
}

data "aws_iam_policy_document" "jenkins_deploy_policy_doc" {
  statement {
    sid     = "CloudFormationCore"
    effect  = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackEvents",
      "cloudformation:DescribeStackResources",
      "cloudformation:DescribeChangeSet",
      "cloudformation:ListChangeSets",
      "cloudformation:CreateChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:GetTemplate",
      "cloudformation:GetTemplateSummary",
      "cloudformation:ValidateTemplate",
      "cloudformation:CancelUpdateStack",
      "cloudformation:ListStacks",
      "cloudformation:ListStackResources",
      "cloudformation:ListExports",
      "cloudformation:ListImports",
      "cloudformation:TagResource",
      "cloudformation:UntagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "LambdaDeployment"
    effect  = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:DeleteAlias",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:ListFunctions",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource"
    ]
    resources = ["*"]
  }

  statement {
    sid     = "IamPassRoleRestrictedToServices"
    effect  = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["arn:aws:iam::*:role/*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com", "cloudformation.amazonaws.com"]
    }
  }

  statement {
    sid     = "StsReadOnly"
    effect  = "Allow"
    actions = [
      "sts:GetCallerIdentity",
      "sts:GetSessionToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "jenkins_deploy_policy" {
  name        = "jenkins-deploy-ci-cd"
  path        = "/"
  description = "Permissions for jenkins-deploy to deploy AWS Lambda and manage CloudFormation stacks"
  policy      = data.aws_iam_policy_document.jenkins_deploy_policy_doc.json
  tags        = local.common_tags
}

resource "aws_iam_user_policy_attachment" "jenkins_deploy_attach" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.jenkins_deploy_policy.arn
}