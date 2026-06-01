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
      "s3:ListBucket"
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
}

resource "aws_iam_role_policy" "s3_read_app_config" {
  name   = "s3-read-app-config-policy"
  role   = aws_iam_role.ec2_app_config_reader.id
  policy = data.aws_iam_policy_document.s3_read_app_config.json
}

resource "aws_iam_instance_profile" "ec2_app_config_reader" {
  name = "ec2-app-config-reader-profile"
  role = aws_iam_role.ec2_app_config_reader.name
}