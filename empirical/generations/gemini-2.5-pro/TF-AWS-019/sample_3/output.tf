resource "aws_cloudwatch_metric_alarm" "ec2_cpu_utilization_high" {
  alarm_name          = "ec2-cpu-utilization-high-i-0123456789abcdef"
  alarm_description   = "Fires when EC2 instance i-0123456789abcdef CPU utilization exceeds 80% for 10 consecutive minutes."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 10
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }
}