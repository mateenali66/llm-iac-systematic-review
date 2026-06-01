resource "aws_iam_user" "jenkins_deploy" {
  name = "jenkins-deploy"
  path = "/system/cicd/"

  tags = {
    Description = "User for CI/CD pipeline to deploy Lambda and CloudFormation"
  }
}

resource "aws_iam_policy" "jenkins_deploy_policy" {
  name