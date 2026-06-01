data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_role" {
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

data "aws_iam_policy_document" "s3_read" {
  statement {
    sid     = "ListAndGetBucketLocation"
    effect  = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::app-config-bucket"
    ]
  }

  statement {
    sid     = "GetObjects"
    effect  = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::app-config-bucket/*"
    ]
  }
}

resource "aws_iam_role" "ec2_app_config_read" {
  name               = "ec2-app-config-read-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "IAM role for EC2 instances to read objects from the app-config-bucket"

  tags = {
    Name      = "ec2-app-config-read-role"
    ManagedBy = "Terraform"
    Purpose   = "EC2 read access to app-config-bucket"
  }
}

resource "aws_iam_policy" "ec2_app_config_read" {
  name        = "ec2-app-config-read-policy"
  description = "Policy granting EC2 instances read access to app-config-bucket"
  policy      = data.aws_iam_policy_document.s3_read.json

  tags = {
    Name      = "ec2-app-config-read-policy"
    ManagedBy = "Terraform"
    Purpose   = "EC2 read access to app-config-bucket"
  }
}

resource "aws_iam_role_policy_attachment" "attach_ec2_app_config_read" {
  role       = aws_iam_role.ec2_app_config_read.name
  policy_arn = aws_iam_policy.ec2_app_config_read.arn
}

resource "aws_iam_instance_profile" "ec2_app_config_read" {
  name = "ec2-app-config-read-instance-profile"
  role = aws_iam_role.ec2_app_config_read.name

  tags = {
    Name      = "ec2-app-config-read-instance-profile"
    ManagedBy = "Terraform"
    Purpose   = "EC2 read access to app-config-bucket"
  }
}