resource "aws_iam_role" "ec2_s3_read_role" {
  name = "ec2-s3-read-role"

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

resource "aws_iam_role_policy" "s3_read_policy" {
  name = "s3-read-policy"
  role = aws_iam_role.ec2_s3_read_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectAttributes"
        ]
        Effect = "Allow"
        Resource = "arn:aws:s3:::app-config-bucket/*"
      },
      {
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Effect = "Allow"
        Resource = "arn:aws:s3:::app-config-bucket"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_s3_read_profile" {
  name = "ec2-s3-read-profile"
  role = aws_iam_role.ec2_s3_read_role.name
}