data "aws_partition" "current" {}

variable "deployment_tag_key" {
  type = string
  description = "Tag key used to scope Jenkins deploy permissions to specific resources."
}

variable "deployment_tag_value" {
  type = string
  description = "Tag value used to scope Jenkins deploy permissions to specific resources."
}

variable "allowed_passrole_arns" {
  type        = list(string)
  default     = []
  description = "List of IAM role ARNs that CloudFormation is allowed to assume via iam:PassRole."
}

variable "permissions_boundary_policy_arn" {
  type        = string
  default     = null
  description = "Optional permissions boundary policy ARN to apply to the IAM user."
}

resource "aws_iam_user" "jenkins_deploy" {
  name                 = "jenkins-deploy"
  path                 = "/service-accounts/"
  permissions_boundary = var.permissions_boundary_policy_arn

  tags = {
    Name      = "jenkins-deploy"
    ManagedBy = "Terraform"
    Purpose   = "CI/CD deployments for Lambda and CloudFormation"
  }
}

data "aws_iam_policy_document" "jenkins_deploy" {
  statement {
    sid     = "LambdaCreateWithRequiredTag"
    actions = [
      "lambda:CreateFunction",
      "lambda:PublishLayerVersion"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/${var.deployment_tag_key}"
      values   = [var.deployment_tag_value]
    }
  }

  statement {
    sid     = "LambdaManageTaggedResources"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:DeleteFunction",
      "lambda:TagResource",
      "lambda:UntagResource"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.deployment_tag_key}"
      values   = [var.deployment_tag_value]
    }
  }

  statement {
    sid     = "LambdaReadTaggedResources"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:ListAliases",
      "lambda:ListVersionsByFunction",
      "lambda:ListTags",
      "lambda:GetLayerVersion"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.deployment_tag_key}"
      values   = [var.deployment_tag_value]
    }
  }

  statement {
    sid     = "CloudFormationCreateWithRequiredTag"
    actions = [
      "cloudformation:CreateStack"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/${var.deployment_tag_key}"
      values   = [var.deployment_tag_value]
    }
  }

  statement {
    sid     = "CloudFormationManageTaggedStacks"
    actions = [
      "cloudformation:UpdateStack",
      "cloudformation:DeleteStack",
      "cloudformation:SetStackPolicy",
      "cloudformation:GetTemplate"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.deployment_tag_key}"
      values   = [var.deployment_tag_value]
    }
  }

  statement {
    sid     = "CloudFormationChangeSetsForTaggedStacks"
    actions = [
      "cloudformation:CreateChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:DescribeChangeSet"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.deployment_tag_key}"
      values   = [var.deployment_tag_value]
    }
  }

  statement {
    sid     = "CloudFormationDescribeTaggedStacks"
    actions = [
      "cloudformation:DescribeStacks",
      "cloudformation:DescribeStackResources",
      "cloudformation:DescribeStackEvents"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.deployment_tag_key}"
      values   = [var.deployment_tag_value]
    }
  }

  statement {
    sid     = "CloudFormationListStacksMinimal"
    actions = [
      "cloudformation:ListStacks"
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowPassSpecificRoles"
    actions = [
      "iam:PassRole"
    ]
    resources = var.allowed_passrole_arns
  }

  statement {
    sid    = "DenyConsolePasswordManagement"
    effect = "Deny"
    actions = [
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:ChangePassword"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:user/${aws_iam_user.jenkins_deploy.name}"
    ]
  }
}

resource "aws_iam_policy" "jenkins_deploy" {
  name        = "jenkins-deploy-ci-policy"
  description = "Least-privilege policy for Jenkins to deploy Lambda functions and manage tagged CloudFormation stacks"
  policy      = data.aws_iam_policy_document.jenkins_deploy.json
}

resource "aws_iam_user_policy_attachment" "jenkins_deploy" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.jenkins_deploy.arn
}