provider "aws" {
  region = "us-west-2"
}

resource "aws_db_subnet_group" "saas_database" {
  name       = "saas-database-subnet-group"
  subnet_ids = [aws_subnet.database_subnet_1.id, aws_subnet.database_subnet_2.id]

  tags = {
    Name = "Saas Database Subnet Group"
  }
}

resource "aws_subnet" "database_subnet_1" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.saas_vpc.id
  availability_zone = "us-west-2a"

  tags = {
    Name = "Saas Database Subnet 1"
  }
}

resource "aws_subnet" "database_subnet_2" {
  cidr_block = "10.0.2.0/24"
  vpc_id     = aws_vpc.saas_vpc.id
  availability_zone = "us-west-2b"

  tags = {
    Name = "Saas Database Subnet 2"
  }
}

resource "aws_vpc" "saas_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Saas VPC"
  }
}

resource "aws_db_instance" "saas_database" {
  allocated_storage    = 100
  engine               = "postgres"
  engine_version       = "15.2"
  instance_class       = "db.t3.medium"
  db_subnet_group_name = aws_db_subnet_group.saas_database.name
  vpc_security_group_ids = [aws_security_group.saas_database_sg.id]
  db_name                 = "saasdb"
  username               = "saasuser"
  password               = "saaspassword"
  parameter_group_name  = aws_db_parameter_group.saas_database_pg.name
  backup_retention_period = 30
  skip_final_snapshot    = false
  deletion_protection    = true
  multi_az              = true
}

resource "aws_db_parameter_group" "saas_database_pg" {
  name   = "saas-database-pg"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_error_verbosity"
    value = "DEFAULT"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "shared_buffers"
    value = "512"
  }

  parameter {
    name  = "maintenance_work_mem"
    value = "64"
  }

  parameter {
    name  = "work_mem"
    value = "8"
  }

  parameter {
    name  = "effective_cache_size"
    value = "1024"
  }
}

resource "aws_security_group" "saas_database_sg" {
  name        = "saas-database-sg"
  description = "Saas Database Security Group"
  vpc_id      = aws_vpc.saas_vpc.id

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

  tags = {
    Name = "Saas Database Security Group"
  }
}