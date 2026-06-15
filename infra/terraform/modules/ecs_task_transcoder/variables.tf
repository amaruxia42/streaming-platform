variable "project_name" {
  description = "streaming platform name"
  type        = string
}

variable "environment" {
  description = "working environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "container_image" {
  description = "Container image"
  type        = string
}

variable "execution_role_arn" {
  description = "Execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log name"
  type        = string
}

variable "cpu" {
  type    = number
  default = 4096
}

variable "memory" {
  type    = number
  default = 8192
}