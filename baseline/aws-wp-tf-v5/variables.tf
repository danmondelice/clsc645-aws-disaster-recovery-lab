variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS access key"
  type        = string
  default     = "your_key_here"
}

variable "aws_secret_key" {
  description = "AWS secret key"
  type        = string
  sensitive   = true
  default     = "your_secret_key_here"
}

variable "aws_session_token" {
  description = "AWS session token for temporary credentials"
  type        = string
  sensitive   = true
  default     = ""
}

// VPC
variable "vpc_cidr_block" {
  description = "VPC network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr_block" {
  description = "Public Subnet A"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr_block" {
  description = "Public Subnet B"
  type        = string
  default     = "10.0.2.0/24"
}

variable "public_subnet_c_cidr_block" {
  description = "Public Subnet C"
  type        = string
  default     = "10.0.3.0/24"
}

// RDS
variable "db_instance_type" {
  description = "RDS instance type"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "RDS DB name"
  type        = string
  default     = "wordpressdb"
}

variable "db_user" {
  description = "RDS DB username"
  type        = string
  default     = "ecs"
}

variable "db_password" {
  description = "RDS DB password"
  type        = string
  sensitive   = true
  default     = "Qwerty12345-"
}

// cluster
variable "ecs_cluster_name" {
  description = "ECS cluster Name"
  type        = string
  default     = "ecs-wordpress"
}