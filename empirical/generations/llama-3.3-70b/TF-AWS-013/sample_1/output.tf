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
      name      = "api-server"
      image      = "api-server-image:latest"
      cpu        = 256
      essential = true
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
    container_port   = 8080
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
  name        = "api-server-sg"
  description = "API server security group"
  vpc_id      = aws_vpc.api_server.id

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

  tags = {
    Environment = "production"
  }
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
  certificate_arn    = "arn:aws:acm:us-west-2:123456789012:certificate/12345678-1234-1234-1234-123456789012"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_server.arn
  }
}

resource "aws_lb_listener" "api_server_http" {
  load_balancer_arn = aws_lb.api_server.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}