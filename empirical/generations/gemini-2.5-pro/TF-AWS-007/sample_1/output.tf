data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_s3_read_role" {
  name               = "ec2-s3-app-config-read-role"
  description        = "Allows EC2 instances to read objects from the app-config-bucket S3 bucket."
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json

  tags = {
    Name = "EC2S3AppConfigReadRole"
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
    sid    = "ReadObjects"
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
  name        = "ec2-s3-app-config-read-policy"
  description = "Allows reading objects from the app-config-bucket S3 bucket."
  policy      = data.aws_iam_policy_document.s3_read_policy_document.json
}

resource "aws_iam_role_policy_attachment" "s3_read_attachment" {
  role       = aws_iam_role.ec2_s3_read_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-s3-app-config-read-profile"
  role = aws_iam_role.ec2_s3_read_role.name
}