variable "vpc_id" {
  description = "streaming platform vpc id"
  type        = string
}

variable "environment" {
  description = "working environment"
  type        = string
}

variable "project_name" {
  description = "project description"
  type        = string
}

variable "container_port" {
  description = "container application port numbers"
  type        = number
}

variable "app_subnet_cidrs" {
  description = "private app subnet cidrs"
  type        = list(string)
}