data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "s3_read_role" {
  name               = "app-config-s3-read-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
  path               = "/"

  tags = {
    Name        = "app-config-s3-read-ec2-role"
    ManagedBy   = "Terraform"
    Description = "Allows EC2 instances to read objects from the app-config-bucket S3 bucket"
  }
}

data "aws_iam_policy_document" "s3_read_policy_document" {
  statement {
    sid    = "ListBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::app-config-bucket",
    ]
  }

  statement {
    sid    = "GetObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
    ]
    resources = [
      "arn:aws:s3:::app-config-bucket/*",
    ]
  }
}

resource "aws_iam_policy" "s3_read_policy" {
  name        = "app-config-s3-read-policy"
  description = "Policy to allow reading objects from the app-config-bucket S3 bucket"
  policy      = data.aws_iam_policy_document.s3_read_policy_document.json
}

resource "aws_iam_role_policy