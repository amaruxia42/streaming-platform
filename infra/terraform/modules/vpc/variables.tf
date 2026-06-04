variable "environment" {
  description = "working environment"
  type        = string
}

variable "project_name" {
  description = "project description"
  type        = string
}

variable "vpc_cidr" {
  description = "stream vpc cidr block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "public subnets"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_endpoint_sg_id" {
  description = "CloudWatch Logs Endpoint Security Group"
  type        = string
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
}


