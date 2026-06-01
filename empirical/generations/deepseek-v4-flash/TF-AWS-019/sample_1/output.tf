resource "aws_cloudwatch_metric_alarm" "high_cpu_alarm" {
  alarm_name          = "high-cpu-utilization-i-0123456789abcdef"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm fires when CPU utilization exceeds 80% for 10 consecutive minutes"
  insufficient_data_actions = []
  alarm_actions       = []

  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }
}