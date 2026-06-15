variable "project_name" {
  description = "Streaming platform name"
  type        = string
}

variable "environment" {
  description = "Working environment"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository"
  type        = string
}

variable "video_uploaded_topic_arn" {
  description = "Video uploaded SNS topic ARN"
  type        = string
}

variable "video_processing_queue_arn" {
  description = "Video processing queue ARN"
  type        = string
}

variable "video_processing_queue_url" {
  description = "Video processing queue URL"
  type        = string
}

variable "transcoder_task_definition_arn" {
  description = "Transcoder task definition ARN"
  type        = string
}

variable "ingest_bucket_arn" {
  description = "S3 ingest bucket ARN"
  type        = string
}

variable "delivery_bucket_arn" {
  description = "S3 delivery bucket ARN"
  type        = string
}