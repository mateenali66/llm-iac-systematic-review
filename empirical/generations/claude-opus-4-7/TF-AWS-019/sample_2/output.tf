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
  description = "EC2 instance ID to monitor for high CPU utilization"
  type        = string
  default     = "i-0123456789abcdef"
}

variable "alarm_sns_topic_arns" {
  description = "List of SNS topic ARNs to notify when the alarm changes state"
  type        = list(string)
  default     = []
}

variable "cpu_threshold_percent" {
  description = "CPU utilization percentage threshold that triggers the alarm"
  type        = number
  default     = 80
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "ec2-${var.instance_id}-high-cpu-utilization"
  alarm_description   = "Triggers when CPU utilization on EC2 instance ${var.instance_id} exceeds ${var.cpu_threshold_percent}% for 10 consecutive minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_threshold_percent
  period              = 60
  evaluation_periods  = 10
  datapoints_to_alarm = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.instance_id
  }

  actions_enabled           = true
  alarm_actions             = var.alarm_sns_topic_arns
  ok_actions                = var.alarm_sns_topic_arns
  insufficient_data_actions = []

  tags = {
    Name        = "ec2-${var.instance_id}-high-cpu-utilization"
    ManagedBy   = "Terraform"
    Environment = "production"
    Resource    = var.instance_id
  }
}

output "alarm_arn" {
  description = "ARN of the CloudWatch CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.ec2_high_cpu.arn
}

output "alarm_name" {
  description = "Name of the CloudWatch CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.ec2_high_cpu.alarm_name
}