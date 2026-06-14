variable "project_name" {
  description = "Streaming platform name"
  type        = string
}

variable "environment" {
  description = "Working environment"
  type        = string
}

variable "video_processing_queue_arn" {
  description = "Video processing queue ARN"
  type        = string
}

variable "lambda_role_arn" {
  description = "Lambda execution role ARN"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "transcoder_task_definition_arn" {
  description = "FFmpeg task definition ARN"
  type        = string
}