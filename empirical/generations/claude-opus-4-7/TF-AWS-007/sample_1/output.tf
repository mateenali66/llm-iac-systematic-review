variable "bucket_name" {
  description = "Name of the S3 bucket the EC2 instance can read from"
  type        = string
  default     = "app-config-bucket"
}

variable "role_name" {
  description = "Name of the IAM role"
  type        = string
  default     = "ec2-s3-read-role"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Purpose   = "EC2 read access to app-config-bucket"
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

  tags = var.tags
}

data "aws_iam_policy_document" "s3_read" {
  statement {
    sid    = "ListConfigBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = ["arn:aws:s3:::${var.bucket_name}"]
  }

  statement {
    sid    = "ReadConfigBucketObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["arn:aws:s3:::${var.bucket_name}/*"]
  }
}

resource "aws_iam_policy" "s3_read" {
  name        = "${var.role_name}-s3-read"
  description = "Read-only access to s3://${var.bucket_name}"
  policy      = data.aws_iam_policy_document.s3_read.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  role       = aws_iam_role.ec2_s3_read.name
  policy_arn = aws_iam_policy.s3_read.arn
}

resource "aws_iam_instance_profile" "ec2_s3_read" {
  name = var.role_name
  role = aws_iam_role.ec2_s3_read.name
  tags = var.tags
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.ec2_s3_read.arn
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.ec2_s3_read.name
}

output "instance_profile_name" {
  description = "Name of the instance profile to attach to EC2 instances"
  value       = aws_iam_instance_profile.ec2_s3_read.name
}

output "instance_profile_arn" {
  description = "ARN of the instance profile"
  value       = aws_iam_instance_profile.ec2_s3_read.arn
}