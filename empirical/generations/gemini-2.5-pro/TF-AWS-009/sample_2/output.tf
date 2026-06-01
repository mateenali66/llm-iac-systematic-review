variable "aws_region" {
  description = "The AWS region to deploy resources."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project or application."
  type        = string
  default     = "saas-app"
}

variable "environment" {
  description = "The deployment environment (e.g., prod, staging)."
  type        = string
  default     = "prod"
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "db_instance_class" {
  description = "The instance class for the RDS database."
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "The initial allocated storage in GB for the database."
  type        = number
  default     = 100
}

variable "db_max_allocated_storage" {
  description = "The maximum storage in GB to which the database can scale."
  type        = number
  default     = 500
}

variable "db_name" {
  description = "The name of the database to create."
  type        = string
  default     = "saas_primary_db"
}

variable "db_master_username" {
  description = "The master username for the database."
  type        = string
  default     = "saasadmin"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "