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

data "aws_iam_policy_document" "s3_read_app_config" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::app-config-bucket",
      "arn:aws:s3:::app-config-bucket/*"
    ]
  }
}

resource "aws_iam_role" "ec2_s3_read_role" {
  name               = "ec2-s3-read-app-config-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "IAM role for EC2 instances to read objects from app-config-bucket"
}

resource "aws_iam_role_policy" "s3_read_app_config" {
  name   = "s3-read-app-config-policy"
  role   = aws_iam_role.ec2_s3_read_role.id
  policy = data.aws_iam_policy_document.s3_read_app_config.json
}

resource "aws_iam_instance_profile" "ec2_s3_read_profile" {
  name = "ec2-s3-read-app-config-profile"
  role = aws_iam_role.ec2_s3_read_role.name
}