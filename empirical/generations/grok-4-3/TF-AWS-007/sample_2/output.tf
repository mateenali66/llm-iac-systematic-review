resource "aws_iam_role" "ec2_app_config_reader" {
  name               = "ec2-app-config-reader"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  permissions_boundary = null
  max_session_duration = 3600
}

resource "aws_iam_policy" "s3_read_only" {
  name = "app-config-bucket-read-only"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "arn:aws:s3:::app-config-bucket/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::app-config-bucket"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read_attach" {
  role       = aws_iam_role.ec2_app_config_reader.name
  policy_arn = aws_iam_policy.s3_read_only.arn
}

resource "aws_iam_instance_profile" "ec2_app_config_profile" {
  name = "ec2-app-config-profile"
  role = aws_iam_role.ec2_app_config_reader.name
}