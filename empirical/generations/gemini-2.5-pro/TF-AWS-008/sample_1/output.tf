resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/system/"

  tags = {
    ManagedBy   = "Terraform"
    Description = "IAM user for Jenkins CI/CD pipeline"
  }
}

resource "aws_iam_policy" "jenkins_deploy_policy"