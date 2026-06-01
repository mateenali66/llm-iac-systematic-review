data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "s3_read_app_config" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::app-config-bucket",
      "arn:aws:s3:::app-config-bucket/*"
    ]
  }
}

resource "aws_iam_role" "ec2_app_config_reader" {
  name               = "ec2-app-config-reader-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  description        = "IAM role for EC2 instances to read objects from app-config-bucket"

  tags = {
    Name        = "ec2-app-config-reader-role"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_policy" "s3_read_app_config" {
  name        = "s3-read-app-config-policy"
  description = "Policy to allow reading objects from app-config-bucket"
  policy      = data.aws_iam_policy_document.s3_read_app_config.json

  tags = {
    Name        = "s3-read-app-config-policy"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_app_config_reader" {
  role       = aws_iam_role.ec2_app_config_reader.name
  policy_arn = aws_iam_policy.s3_read_app_config.arn
}

resource "aws_iam_instance_profile" "ec2_app_config_reader" {
  name = "ec2-app-config-reader-profile"
  role = aws_iam_role.ec2_app_config_reader.name

  tags = {
    Name        = "ec2-app-config-reader-profile"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}