terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "name" {
  type        = string
  description = "Base name/prefix for resources"
  default     = "api"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be created"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs for ALB"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks"
}

variable "container_image" {
  type        = string
  description = "Container image for the API (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com/api:latest)"
}

variable "desired_count" {
  type        = number
  description = "Desired number of tasks"
  default     = 2
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of tasks for autoscaling"
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of tasks for autoscaling"
  default     = 10
}

variable "container_cpu" {
  type        = number
  description = "Task CPU units"
  default     = 512
}

variable "container_memory" {
  type        = number
  description = "Task memory (MiB)"
  default     = 1024
}

variable "health_check_path" {
  type        = string
  description = "ALB target group health check path"
  default     = "/health"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the HTTPS listener"
}

variable "environment" {
  type        = map(string)
  description = "Environment variables for the container"
  default     = {}
}

variable "container_secrets" {
  type        = map(string)
  description = "Map of environment variable name to Secrets Manager or SSM Parameter ARN"
  default     = {}
}

variable "task_execution_role_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the task execution role"
  default     = []
}

variable "task_role_policy_arns" {
  type        = list(string)
  description = "Policy ARNs to attach to the task role"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

locals {
  alb_name        = "${var.name}-alb"
  tg_name         = "${var.name}-tg"
  cluster_name    = "${var.name}-cluster"
  service_name    = "${var.name}-svc"
  log_group_name  = "/ecs/${var.name}"
  container_name  = var.name
  container_port  = 8080

  environment_list = [
    for k, v in var.environment : {
      name  = k
      value = v
    }
  ]

  secrets_list = [
    for k, v in var.container_secrets : {
      name      = k
      valueFrom = v
    }
  ]
}

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_security_group" "service" {
  name        = "${var.name}-svc-sg"
  description = "ECS service security group"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Allow ALB to reach service on container port"
    from_port       = local.container_port
    to_port         = local.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, { Name = "${var.name}-svc-sg" })
}

resource "aws_lb" "this" {
  name               = local.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids
  enable_deletion_protection = true
  drop_invalid_header_fields = true

  access_logs {
    enabled = false
  }

  tags = merge(var.tags, { Name = local.alb_name })
}

resource "aws_lb_target_group" "this" {
  name        = local.tg_name
  port        = local.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
    protocol            = "HTTP"
  }

  tags = merge(var.tags, { Name = local.tg_name })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.this.arn
      }
      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-https-listener" })
}

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-http-redirect" })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = 30
  tags              = merge(var.tags, { Name = local.log_group_name })
}

data "aws_iam_policy_document" "task_execution_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.name}-task-exec-role"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume.json
  tags               = merge(var.tags, { Name = "${var.name}-task-exec-role" })
}

resource "aws_iam_role_policy_attachment" "task_execution_default" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_execution_additional" {
  for_each   = toset(var.task_execution_role_policy_arns)
  role       = aws_iam_role.task_execution.name
  policy_arn = each.value
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume.json
  tags               = merge(var.tags, { Name = "${var.name}-task-role" })
}

resource "aws_iam_role_policy_attachment" "task_policies" {
  for_each   = toset(var.task_role_policy_arns)
  role       = aws_iam_role.task.name
  policy_arn = each.value
}

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name
  tags = merge(var.tags, { Name = local.cluster_name })
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.container_cpu)
  memory                   = tostring(var.container_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  ephemeral_storage {
    size_in_gib = 50
  }

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = local.container_port
          hostPort      = local.container_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]
      environment = local.environment_list
      secrets     = local.secrets_list
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.region
          awslogs-stream-prefix = local.container_name
          mode                  = "non-blocking"
          max-buffer-size       = "25m"
        }
      }
    }
  ])

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_ecs_service" "this" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  platform_version = "1.4.0"

  deployment_controller {
    type = "ECS"
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  enable_execute_command             = true

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  lifecycle {
    ignore_changes = [task_definition] # allows rolling updates via new task defs without forcing replacement
  }

  tags = merge(var.tags, { Name = local.service_name })

  depends_on = [
    aws_lb_listener.https
  ]
}

resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scale" {
  name               = "${var.name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = 50
    scale_in_cooldown  = 300
    scale_out_cooldown = 120
  }
}

output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "service_name" {
  value       = aws_ecs_service.this.name
  description = "Name of the ECS service"
}

output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "Name of the ECS cluster"
}