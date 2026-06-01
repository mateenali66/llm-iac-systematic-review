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
  description = "EC2 instance ID to monitor"
  type        = string
  default     = "i-0123456789abcdef"
}

variable "alarm_actions" {
  description = "List of ARNs (e.g., SNS topics) to notify when the alarm transitions to ALARM state"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "List of ARNs to notify when the alarm transitions to OK state"
  type        = list(string)
  default     = []
}

resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu" {
  alarm_name          = "ec2-${var.instance_id}-high-cpu-utilization"
  alarm_description   = "Triggers when EC2 instance ${var.instance_id} CPU utilization exceeds 80% for 10 consecutive minutes."

  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  unit                = "Percent"

  period              = 60
  evaluation_periods  = 10
  datapoints_to_alarm = 10

  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = var.instance_id
  }

  actions_enabled = true
  alarm_actions   = var.alarm_actions
  ok_actions      = var.ok_actions

  tags = {
    Name        = "ec2-${var.instance_id}-high-cpu-utilization"
    ManagedBy   = "Terraform"
    Environment = "production"
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