resource "aws_iam_role" "ec2_app_config_reader" {
  name               = "ec2-app-config-reader"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = {
    Name        = "ec2-app-config-reader"
    Environment = "production"
  }
}

resource "aws_iam_policy" "s3_app_config_read" {
  name        = "app-config-bucket-read"
  description = "Allow EC2 to read objects from app-config-bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:GetObject"
      Resource = "arn:aws:s3:::app-config-bucket/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_read" {
  role       = aws_iam_role.ec2_app_config_reader.name
  policy_arn = aws_iam_policy.s3_app_config_read.arn
}

resource "aws_iam_instance_profile" "ec2_app_config_profile" {
  name = "ec2-app-config-profile"
  role = aws_iam_role.ec2_app_config_reader.name
}