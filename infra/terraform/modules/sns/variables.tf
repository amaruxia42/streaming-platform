variable "environment" {
  description = "working environment"
  type        = string
}

variable "project_name" {
  description = "project description"
  type        = string
}

variable "video_processing_queue_arn" {

  description = "Video processing SQS queue ARN"

  type = string
}