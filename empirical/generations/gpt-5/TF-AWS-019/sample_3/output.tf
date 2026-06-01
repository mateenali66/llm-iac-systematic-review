resource "aws_cloudwatch_metric_alarm" "ec2_cpu_utilization_high_10m" {
  alarm_name          = "ec2-i-0123456789abcdef-cpu-utilization-high-10m"
  alarm_description   = "Triggers when EC2 instance i-0123456789abcdef CPU utilization exceeds 80% for 10 consecutive minutes."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  unit                = "Percent"
  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }
  treat_missing_data = "notBreaching"
  actions_enabled    = true
}