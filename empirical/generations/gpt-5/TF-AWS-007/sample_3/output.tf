variable "s3_bucket_name" {
  type    = string
  default = "app-config-bucket"
}

locals {
  tags = {
    ManagedBy = "Terraform"
    Purpose   = "EC2 role for reading app configuration from S3"
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

resource "aws_iam_role" "ec2_app_config_reader" {
  name               = "ec2-app-config-reader-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "IAM role assumed by EC2 instances to read application config from S3"
  max_session_duration = 3600

  tags = local.tags
}

data "aws_iam_policy_document" "s3_read_app_config" {
  statement {
    sid     = "ListBucket"
    effect  = "Allow"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}"
    ]
  }

  statement {
    sid     = "ReadObjects"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = [
      "arn:aws:s3:::${var.s3_bucket_name}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_read_app_config" {
  name        = "ec2-read-app-config-bucket"
  description = "Allow EC2 instances to list and read objects from the app-config S3 bucket"
  policy      = data.aws_iam_policy_document.s3_read_app_config.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_s3_read_app_config" {
  role       = aws_iam_role.ec2_app_config_reader.name
  policy_arn = aws_iam_policy.s3_read_app_config.arn
}

resource "aws_iam_instance_profile" "ec2_app_config_reader" {
  name = "ec2-app-config-reader-profile"
  role = aws_iam_role.ec2_app_config_reader.name

  tags = local.tags
}