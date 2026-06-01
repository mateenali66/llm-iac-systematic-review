resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "ec2-i-0123456789abcdef-high-cpu-utilization"
  alarm_description   = "This alarm fires when the EC2 instance i-0123456789abcdef CPU utilization exceeds 80% for 10 consecutive minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "10"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }

  tags = {
    ManagedBy = "Terraform"
    Service   = "EC2"
  }
}