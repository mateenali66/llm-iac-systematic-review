provider "aws" {
  region = "us-west-2"
}

resource "aws_db_instance" "primary_database" {
  identifier           = "primary-database"
  instance_class       = "db.t3.medium"
  engine               = "postgres"
  engine_version       = "15.2"
  username             = "postgres"
  password             = random_password.password.result
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.primary_database_sg.id]
  db_subnet_group_name = aws_db_subnet_group.primary_database_subnet_group.name
  storage_type         = "gp3"
  allocated_storage    = 100
  max_allocated_storage = 1000
  backup_retention_period = 30
  backup_window        = "02:00-03:00"
  maintenance_window   = "sun:03:00-sun:04:00"
  deletion_protection  = true
  skip_final_snapshot  = false
  apply_immediately    = true
}

resource "random_password" "password" {
  length = 16
  special = true
}

resource "aws_security_group" "primary_database_sg" {
  name        = "primary-database-sg"
  description = "Security group for primary database"
  vpc_id      = aws_vpc.primary_vpc.id

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

resource "aws_vpc" "primary_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "primary_database_subnet_1" {
  vpc_id            = aws_vpc.primary_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-2a"
}

resource "aws_subnet" "primary_database_subnet_2" {
  vpc_id            = aws_vpc.primary_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-west-2b"
}

resource "aws_db_subnet_group" "primary_database_subnet_group" {
  name       = "primary-database-subnet-group"
  subnet_ids = [aws_subnet.primary_database_subnet_1.id, aws_subnet.primary_database_subnet_2.id]
}

output "database_instance_address" {
  value = aws_db_instance.primary_database.address
}

output "database_instance_port" {
  value = aws_db_instance.primary_database.port
}

output "database_instance_username" {
  value = aws_db_instance.primary_database.username
}

output "database_instance_password" {
  value = random_password.password.result
  sensitive = true
}