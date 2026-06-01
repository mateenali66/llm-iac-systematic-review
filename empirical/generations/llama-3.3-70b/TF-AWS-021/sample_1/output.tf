provider "aws" {
  region = "us-west-2"
}

resource "aws_elastic_beanstalk_environment" "nodejs_env" {
  name                = "nodejs-env"
  application         = aws_elastic_beanstalk_application.nodejs_app.name
  solution_stack_name = "64bit amazon linux 2022 v3.4.1 running Node.js 18"
  version_label       = aws_elastic_beanstalk_application_version.nodejs_app_version.label

  setting {
    namespace = "aws:ec2:instance"
    name      = "InstanceType"
    value     = "t3.small"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthchecking"
    name      = "HealthCheckURL"
    value     = "/"
  }
}

resource "aws_elastic_beanstalk_application" "nodejs_app" {
  name        = "nodejs-app"
  description = "Node.js 18 application"
}

resource "aws_elastic_beanstalk_application_version" "nodejs_app_version" {
  name        = "nodejs-app-version"
  application = aws_elastic_beanstalk_application.nodejs_app.name
  description = "Initial version"
  bucket      = "my-bucket"
  key         = "nodejs-app.zip"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_object" "nodejs_app_zip" {
  bucket = aws_s3_bucket.my_bucket.id
  key    = "nodejs-app.zip"
  source = "./path/to/nodejs-app.zip"
  etag   = filemd5("./path/to/nodejs-app.zip")
}