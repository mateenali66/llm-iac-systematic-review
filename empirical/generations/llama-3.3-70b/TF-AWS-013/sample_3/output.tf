provider "aws" {
  region = "us-west-2"
}

resource "aws_ecs_cluster" "api_server" {
  name = "api-server-cluster"
}

resource "aws_ecs_task_definition" "api_server" {
  family                = "api-server-task"
  cpu                    = 256
  memory                = 512
  network_mode          = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn   = aws_iam_role.ecs_task_execution.arn
  container_definitions = jsonencode([
    {
      name        = "api-server"
      image       = "api-server-image:latest"
      cpu         = 256
      memory      = 512
      essential   = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}

resource "aws_iam_role" "ecs_task_execution" {
  name        = "ecs-task-execution-role"
  description = "ECS task execution role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_service" "api_server" {
  name            = "api-server-service"
  cluster         = aws_ecs_cluster.api_server.name
  task_definition = aws_ecs_task_definition.api_server.arn
  launch_type     = "FARGATE"
  desired_count    = 1

  network_configuration {
    subnets         = [aws_subnet.api_server.id]
    security_groups = [aws_security_group.api_server.id]
    assign_public_ip = "ENABLED"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_server.arn
    container_name   = "api-server"
    container_port    = 8080
  }
}

resource "aws_vpc" "api_server" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "api_server" {
  vpc_id            = aws_vpc.api_server.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_security_group" "api_server" {
  vpc_id      = aws_vpc.api_server.id
  name        = "api-server-sg"
  description = "Security group for API server"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "api_server" {
  name               = "api-server-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.api_server.id]
  subnets            = [aws_subnet.api_server.id]

  enable_deletion_protection = false
}

resource "aws_lb_target_group" "api_server" {
  name     = "api-server-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.api_server.id
}

resource "aws_lb_listener" "api_server" {
  load_balancer_arn = aws_lb.api_server.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.api_server.arn

  default_action {
    target_group_arn = aws_lb_target_group.api_server.arn
    type             = "forward"
  }
}

resource "aws_acm_certificate" "api_server" {
  domain_name       = "api.example.com"
  validation_method = "DNS"
}

resource "aws_route53_record" "api_server" {
  name    = "api.example.com"
  type    = "A"
  zone_id = aws_route53_zone.api_server.id

  alias {
    name                   = aws_lb.api_server.dns_name
    zone_id               = aws_lb.api_server.zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_zone" "api_server" {
  name = "example.com"
}