resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high_10m" {
  alarm_name          = "ec2-cpu-utilization-high-10m-i-0123456789abcdef"
  alarm_description   = "Alarm when EC2 instance i-0123456789abcdef CPU > 80% for 10 consecutive minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 80
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  unit                = "Percent"

  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }

  treat_missing_data = "notBreaching"
  actions_enabled    = true

  tags = {
    Name        = "ec2-cpu-utilization-high-10m"
    ManagedBy   = "terraform"
    Environment = "prod"
  }
}