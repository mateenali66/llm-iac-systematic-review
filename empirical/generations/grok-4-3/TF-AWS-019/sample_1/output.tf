resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "ec2-high-cpu-i-0123456789abcdef"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 10
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeded 80% for 10 consecutive minutes"
  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }
  treat_missing_data = "missing"
}