provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_role" "ec2_s3_reader" {
  name        = "ec2-s3-reader-role"
  description = "IAM role for EC2 instance to read from S3 bucket"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_reader_policy" {
  name        = "s3-reader-policy"
  description = "Policy to allow reading from S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::app-config-bucket",
          "arn:aws:s3:::app-config-bucket/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_reader_attach" {
  role       = aws_iam_role.ec2_s3_reader.name
  policy_arn = aws_iam_policy.s3_reader_policy.arn
}

resource "aws_iam_instance_profile" "ec2_s3_reader_profile" {
  name = "ec2-s3-reader-profile"
  role = aws_iam_role.ec2_s3_reader.name
}