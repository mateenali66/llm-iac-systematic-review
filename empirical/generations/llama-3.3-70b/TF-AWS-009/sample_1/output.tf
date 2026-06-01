provider "aws" {
  region = "us-west-2"
}

resource "aws_db_instance" "primary_database" {
  identifier           = "saas-primary-database"
  instance_class      = "db.t3.medium"
  engine               = "postgres"
  engine_version       = "15.2"
  username             = "saas_database_user"
  password             = random_password.database_password.result
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  db_subnet_group_name = aws_db_subnet_group.database_subnet_group.name
  storage_type         = "gp3"
  allocated_storage    = 100
  max_allocated_storage = 1000
  backup_retention_period = 35
  maintenance_window      = "mon:10:30-mon:11:00"
  backup_window           = "10:30-11:00"
  deletion_protection     = true
  skip_final_snapshot     = false
  apply_immediately       = true
}

resource "random_password" "database_password" {
  length = 16
  special = true
}

resource "aws_security_group" "database_sg" {
  name        = "saas-database-sg"
  description = "Security group for SaaS database"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_db_subnet_group" "database_subnet_group" {
  name       = "saas-database-subnet-group"
  subnet_ids = [aws_subnet.database_subnet1.id, aws_subnet.database_subnet2.id]
}

resource "aws_subnet" "database_subnet1" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.vpc.id
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "database_subnet2" {
  cidr_block = "10.0.2.0/24"
  vpc_id     = aws_vpc.vpc.id
  availability_zone = "us-west-2b"
}