resource "aws_cloudwatch_metric_alarm" "ec2_cpu_alarm" {
  alarm_name                = "ec2-cpu-utilization-alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = 10
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = 60
  statistic                 = "Average"
  threshold                 = 80
  alarm_description         = "Alarm when CPU utilization exceeds 80% for 10 minutes"
  insufficient_data_actions = []
  alarm_actions             = []
  ok_actions                = []
  dimensions = {
    InstanceId = "i-0123456789abcdef"
  }
}