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

variable "execution_role_arn" {
  description = "IAM execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ecs task role ARN"
  type        = string
}

variable "app_subnet_ids" {
  description = "private subnets"
  type        = list(string)
}

variable "listener_arn" {
  description = "value"
  type        = string
}

variable "target_group_arn" {
  description = "value"
  type        = string
}

variable "ecs_service_sg_id" {
  description = "Security Group id"
  type        = string
}

variable "ecs_log_group_name" {
  description = "CloudWatch ECS log group name"
  type        = string
}

variable "container_name" {
  description = "Container image name"
  type        = string
}

variable "container_image" {
  description = "container image version"
  type        = string
}

variable "memory" {
  type    = number
  default = 512
}

variable "container_port" {
  type    = number
  default = 80
}

variable "cpu" {
  type    = number
  default = 256
}

variable "desired_count" {
  type    = number
  default = 1
}