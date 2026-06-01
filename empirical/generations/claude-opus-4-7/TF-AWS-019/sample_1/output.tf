terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "instance_id" {
  description = "The EC2 instance ID to monitor."
  type        = string
  default     = "i-0123456789abcdef"
}

variable "alarm_sns_topic_arn" {
  description = "Optional SNS topic ARN to notify on alarm state changes. Leave empty to disable notifications."
  type        = string
  default     = ""
}

locals {
  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "ec2-${var.instance_id}-high-cpu-utilization"
  alarm_description   = "Alarm when EC2 instance ${var.instance_id} CPU utilization exceeds 80% for 10 consecutive minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 10
  datapoints_to_alarm = 10
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = var.instance_id
  }

  actions_enabled           = true
  alarm_actions             = local.alarm_actions
  ok_actions                = local.alarm_actions
  insufficient_data_actions = []

  tags = {
    ManagedBy  = "Terraform"
    InstanceId = var.instance_id
    Severity   = "high"
  }
}

output "alarm_arn" {
  description = "ARN of the CloudWatch alarm."
  value       = aws_cloudwatch_metric_alarm.ec2_high_cpu.arn
}

output "alarm_name" {
  description = "Name of the CloudWatch alarm."
  value       = aws_cloudwatch_metric_alarm.ec2_high_cpu.alarm_name
}