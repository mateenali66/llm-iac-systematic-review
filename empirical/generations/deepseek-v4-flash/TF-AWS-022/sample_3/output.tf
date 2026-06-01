provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "redis" {
  name        = "redis-cache-sg"
  description = "Security group for ElastiCache Redis cluster"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Redis access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "redis-cache-sg"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "redis-cache-subnet-group"
  subnet_ids = data.aws_subnets.private.ids

  tags = {
    Name        = "redis-cache-subnet-group"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "redis-cache-cluster"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 3
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [aws_security_group.redis.id]

  maintenance_window = "sun:05:00-sun:06:00"
  snapshot_window    = "03:00-04:00"
  snapshot_retention_limit = 7

  tags = {
    Name        = "redis-cache-cluster"
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "map-public-ip-on-launch"
    values = [false]
  }
}