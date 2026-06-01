resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high_10m" {
  alarm_name          = "ec2-i-0123456789abcdef-cpu-gt-80-for-10m"
  alarm_description   = "Triggers when EC2 i-0123456789abcdef average CPUUtilization > 80% for 10 consecutive minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  statistic           = "Average"
  period              = 300
  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }
  treat_missing_data = "notBreaching"
  unit               = "Percent"
}