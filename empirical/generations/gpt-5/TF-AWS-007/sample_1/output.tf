data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "s3_read" {
  statement {
    sid     = "BucketReadListing"
    effect  = "Allow"
    actions = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [
      "arn:aws:s3:::app-config-bucket"
    ]
  }

  statement {
    sid     = "ObjectRead"
    effect  = "Allow"
    actions = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = [
      "arn:aws:s3:::app-config-bucket/*"
    ]
  }
}

resource "aws_iam_role" "ec2_s3_read" {
  name               = "ec2-app-config-s3-read-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "IAM role for EC2 instances to read objects from app-config-bucket"

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "EC2 S3 read access"
  }
}

resource "aws_iam_role_policy" "s3_read" {
  name   = "ec2-app-config-s3-read-inline"
  role   = aws_iam_role.ec2_s3_read.id
  policy = data.aws_iam_policy_document.s3_read.json
}

resource "aws_iam_instance_profile" "ec2_s3_read" {
  name = "ec2-app-config-s3-read-profile"
  role = aws_iam_role.ec2_s3_read.name

  tags = {
    ManagedBy = "Terraform"
    Purpose   = "EC2 S3 read access"
  }
}