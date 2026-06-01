data "aws_iam_policy_document" "ec2_assume_role" {
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
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "Allows EC2 instances to read objects from the app-config-bucket S3 bucket."

  tags = {
    Name = "ec2-s3-app-config-read-role"
  }
}

data "aws_iam_policy_document" "s3_read_policy" {
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
    sid    = "GetObject"
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
  path        = "/"
  description = "IAM policy for reading objects from the app-config-bucket S3 bucket."
  policy      = data.aws_iam_policy_document.s3_read_policy.json
}

resource "aws_iam_role_policy_attachment" "ec2_s3_read_attachment" {
  role       = aws_iam_role.ec2_s3_read_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_iam_instance_profile" "ec2_s3_read_profile" {
  name = "ec2-s3-app-config-read-profile"
  role = aws_iam_role.ec2_s3_read_role.name

  tags = {
    Name = "ec2-s3-app-config-read-profile"
  }
}