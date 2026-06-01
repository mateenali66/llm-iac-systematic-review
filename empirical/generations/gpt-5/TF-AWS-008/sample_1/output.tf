variable "allowed_regions" {
  type        = list(string)
  description = "Regions where the jenkins-deploy user is allowed to operate."
  default     = ["us-east-1"]
}

variable "pgp_key" {
  type        = string
  description = "PGP public key to encrypt the access key secret (e.g., keybase:username or base64-encoded PGP key)."
}

resource "aws_iam_user" "jenkins_deploy" {
  name                 = "jenkins-deploy"
  path                 = "/service-users/"
  permissions_boundary = aws_iam_policy.jenkins_deploy_boundary.arn

  tags = {
    ManagedBy = "Terraform"
    Role      = "CI/CD"
    Purpose   = "DeployLambdaAndUpdateCloudFormation"
  }
}

data "aws_iam_policy_document" "jenkins_deploy_allow" {
  statement {
    sid     = "LambdaFunctionScopedActions"
    effect  = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
    ]
    resources = [
      "arn:aws:lambda:*:*:function:*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  statement {
    sid     = "LambdaGlobalActions"
    effect  = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:ListFunctions",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  statement {
    sid     = "CloudFormationChangeAndUpdate"
    effect  = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:Describe*",
      "cloudformation:GetTemplate",
      "cloudformation:GetTemplateSummary",
      "cloudformation:ValidateTemplate",
      "cloudformation:List*",
      "cloudformation:SetStackPolicy",
      "cloudformation:GetStackPolicy",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  statement {
    sid    = "PassRoleToCloudFormationOnly"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::*:role/cfn-*",
      "arn:aws:iam::*:role/cloudformation/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["cloudformation.amazonaws.com"]
    }
  }

  statement {
    sid     = "AllowReadCallerIdentity"
    effect  = "Allow"
    actions = [
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "jenkins_deploy_allow" {
  name        = "jenkins-deploy-policy"
  description = "Least-privilege policy for Jenkins to deploy Lambda and update CloudFormation."
  policy      = data.aws_iam_policy_document.jenkins_deploy_allow.json
}

resource "aws_iam_user_policy_attachment" "jenkins_deploy_attach" {
  user       = aws_iam_user.jenkins_deploy.name
  policy_arn = aws_iam_policy.jenkins_deploy_allow.arn
}

data "aws_iam_policy_document" "jenkins_deploy_boundary" {
  statement {
    sid     = "BoundaryLambdaFunctionScopedActions"
    effect  = "Allow"
    actions = [
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:CreateAlias",
      "lambda:UpdateAlias",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:ListVersionsByFunction",
      "lambda:ListAliases",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:GetPolicy",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
    ]
    resources = [
      "arn:aws:lambda:*:*:function:*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  statement {
    sid     = "BoundaryLambdaGlobalActions"
    effect  = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:ListFunctions",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  statement {
    sid     = "BoundaryCloudFormationChangeAndUpdate"
    effect  = "Allow"
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:UpdateStack",
      "cloudformation:CreateChangeSet",
      "cloudformation:ExecuteChangeSet",
      "cloudformation:DeleteChangeSet",
      "cloudformation:Describe*",
      "cloudformation:GetTemplate",
      "cloudformation:GetTemplateSummary",
      "cloudformation:ValidateTemplate",
      "cloudformation:List*",
      "cloudformation:SetStackPolicy",
      "cloudformation:GetStackPolicy",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }

  statement {
    sid    = "BoundaryPassRoleToCloudFormationOnly"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::*:role/cfn-*",
      "arn:aws:iam::*:role/cloudformation/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["cloudformation.amazonaws.com"]
    }
  }

  statement {
    sid     = "BoundaryAllowReadCallerIdentity"
    effect  = "Allow"
    actions = [
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "DenyOutsideApprovedRegions"
    effect  = "Deny"
    actions = ["*"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

resource "aws_iam_policy" "jenkins_deploy_boundary" {
  name        = "jenkins-deploy-boundary"
  description = "Permissions boundary limiting Jenkins to Lambda and CloudFormation within approved regions."
  policy      = data.aws_iam_policy_document.jenkins_deploy_boundary.json
}

resource "aws_iam_access_key" "jenkins_deploy" {
  user    = aws_iam_user.jenkins_deploy.name
  pgp_key = var.pgp_key
}

output "jenkins_deploy_user_arn" {
  description = "ARN of the Jenkins deploy IAM user."
  value       = aws_iam_user.jenkins_deploy.arn
}

output "jenkins_deploy_access_key_id" {
  description = "Access key ID for the Jenkins deploy user."
  value       = aws_iam_access_key.jenkins_deploy.id
  sensitive   = true
}

output "jenkins_deploy_encrypted_secret_access_key" {
  description = "PGP encrypted secret access key for the Jenkins deploy user."
  value       = aws_iam_access_key.jenkins_deploy.encrypted_secret
  sensitive   = true
}