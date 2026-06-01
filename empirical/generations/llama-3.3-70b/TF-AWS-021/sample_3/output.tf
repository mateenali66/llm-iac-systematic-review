provider "aws" {
  region = "us-west-2"
}

resource "aws_elastic_beanstalk_environment" "nodejs_env" {
  name                = "nodejs-env"
  application         = aws_elastic_beanstalk_application.nodejs_app.name
  solution_stack_name = "64bit amazon linux 2022 v5.4.4 running Node.js 18"
  tier                = "webserver"
  version_label        = aws_elastic_beanstalk_application_version.nodejs_app_version.name

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
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = "nodejs-ec2-key"
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
  bucket      = "nodejs-app-bucket"
  key         = "nodejs-app.zip"
}

resource "aws_s3_bucket" "nodejs_app_bucket" {
  bucket = "nodejs-app-bucket"
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

resource "aws_elastic_beanstalk_configuration_template" "nodejs_config_template" {
  name                = "nodejs-config-template"
  application         = aws_elastic_beanstalk_application.nodejs_app.name
  solution_stack_name = "64bit amazon linux 2022 v5.4.4 running Node.js 18"
}