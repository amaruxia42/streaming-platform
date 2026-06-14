variable "project_name" {
  description = "streaming platform name"
  type        = string
}

variable "environment" {
  description = "working environment"
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

variable "container_name" {
  description = "Container image name"
  type        = string
}

variable "container_port" {
  type    = number
  default = 80
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "health_check_grace_period_seconds" {
  description = "ECS service health check grace period"

  type = number

  default = 120
}

variable "task_definition_arn" {
  description = "Task definition ARN"
  type        = string
}