terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "bucket_name" {
  description = "Name of the S3 bucket the EC2 instance is allowed to read from"
  type        = string
  default     = "app-config-bucket"
}

variable "role_name" {
  description = "Name of the IAM role"
  type        = string
  default     = "ec2-app-config-reader"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "EC2 S3 read access"
  }
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_s3_read" {
  name                 = var.role_name
  description          = "Role allowing EC2 instances to read objects from ${var.bucket_name}"
  assume_role_policy   = data.aws_iam_policy_document.ec2_assume_role.json
  max_session_duration = 3600
  path                 = "/"

  tags = var.tags
}

data "aws_iam_policy_document" "s3_read" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}",
    ]
  }

  statement {
    sid    = "GetObjects"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]

    resources = [
      "arn:aws:s3:::${var.bucket_name}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_read" {
  name        = "${var.role_name}-s3-read"
  description = "Allows read-only access to the ${var.bucket_name} S3 bucket"
  policy      = data.aws_iam_policy_document.s3_read.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_s3_read.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.ec2_s3_read.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_s3_read" {
  name = var.role_name
  role = aws_iam_role.ec2_s3_read.name
  path = "/"

  tags = var.tags
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.ec2_s3_read.name
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.ec2_s3_read.arn
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile to attach to EC2 instances"
  value       = aws_iam_instance_profile.ec2_s3_read.name
}

output "instance_profile_arn" {
  description = "ARN of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_s3_read.arn
}