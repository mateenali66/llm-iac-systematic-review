terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "project_name" {
  type        = string
  description = "Project/Service name"
  default     = "api-service"
}

variable "vpc_id" {
  type        = string
  description = "Target VPC ID"
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
  description = "Container image for the API server"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for SSL termination on the ALB"
}

variable "desired_count" {
  type        = number
  description = "Desired number of ECS service tasks"
  default     = 2
}

variable "container_cpu" {
  type        = number
  description = "CPU units for the task definition"
  default     = 256
}

variable "container_memory" {
  type        = number
  description = "Memory (MiB) for the task definition"
  default     = 512
}

variable "port" {
  type        = number
  description = "Application container port"
  default     = 8080
}

variable "health_check_path" {
  type        = string
  description = "Health check path for the target group"
  default     = "/health"
}

variable "allowed_ingress_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to access the ALB"
  default     = ["0.0.0.0/0"]
}

variable "environment" {
  type        = map(string)
  description = "Environment variables for the container"
  default     = {}
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}

locals {
  common_tags = merge(var.tags, {
    Project   = var.project_name
    ManagedBy = "terraform"
  })
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 30
  tags              = local.common_tags
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project_name}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "${var.project_name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
  tags               = local.common_tags
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.allowed_ingress_cidrs
    content {
      description = "Allow HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_ingress_cidrs
    content {
      description = "Allow HTTP (redirect to HTTPS)"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }
}

resource "aws_security_group" "service" {
  name        = "${var.project_name}-svc-sg"
  description = "ECS service security group"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  ingress {
    description     = "Allow ALB to reach service port"
    from_port       = var.port
    to_port         = var.port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "this" {
  name                       = "${var.project_name}-alb"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = var.public_subnet_ids
  security_groups            = [aws_security_group.alb.id]
  enable_deletion_protection = true
  idle_timeout               = 60
  tags                       = local.common_tags
}

resource "aws_lb_target_group" "this" {
  name_prefix          = substr("${var.project_name}-", 0, 6)
  port                 = var.port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 60

  health_check {
    enabled             = true
    interval            = 30
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    matcher             = "200-399"
    protocol            = "HTTP"
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
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

  tags = local.common_tags
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster" "this" {
  name = var.project_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.project_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.container_cpu)
  memory                   = tostring(var.container_memory)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.project_name
      image     = var.container_image
      essential = true
      portMappings = [
        {
          containerPort = var.port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.this.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = var.project_name
        }
      }
      environment = [
        for k, v in var.environment : {
          name  = k
          value = v
        }
      ]
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  tags = local.common_tags
}

resource "aws_ecs_service" "this" {
  name            = var.project_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  platform_version = "LATEST"

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = var.project_name
    container_port   = var.port
  }

  depends_on = [
    aws_lb_listener.https
  ]

  tags = local.common_tags
}

output "alb_dns_name" {
  value       = aws_lb.this.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "service_name" {
  value       = aws_ecs_service.this.name
  description = "ECS service name"
}

output "cluster_name" {
  value       = aws_ecs_cluster.this.name
  description = "ECS cluster name"
}