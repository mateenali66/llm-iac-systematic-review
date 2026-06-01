resource "aws_cloudwatch_metric_alarm" "ec2_cpu_utilization" {
  alarm_name                = "ec2-cpu-utilization-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 10
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "This metric monitors EC2 instance CPU utilization"
  insufficient_data_actions = []
  treat_missing_data        = "notBreaching"

  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }

  tags = {
    Name        = "EC2-CPU-Utilization-Alarm"
    Environment = "production"
  }
}