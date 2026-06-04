variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "project_name" {
  description = "streaming platform"
  type        = string
}

variable "environment" {
  description = "working  environment"
  type        = string
}

variable "vpc_cidr" {
  description = "stream vpc cidr block"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "public subnet cidr"
  type        = list(string)
}

variable "app_subnet_cidrs" {
  description = "private app subnet cidr"
  type        = list(string)
}

variable "data_subnet_cidrs" {
  description = "private data subnet cidr"
  type        = list(string)
}

variable "container_port" {
  description = "http application port"
  type        = number
}

variable "log_retention_days" {
  description = "number of days to retain logs"
  type        = number
}

variable "cluster_name" {
  description = "kubernetes cluster name"
  type        = string
}

variable "container_name" {
  description = "container image name"
  type        = string
}

variable "container_image" {
  description = "container image version"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository"
  type        = string
}

