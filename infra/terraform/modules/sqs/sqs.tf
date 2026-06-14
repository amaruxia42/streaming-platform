resource "aws_sqs_queue" "video_processing_dlq" {
  name = "${var.project_name}-${var.environment}-video-processing-dlq"

  message_retention_seconds = 1209600

  sqs_managed_sse_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-video-processing-dlq"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sqs_queue" "video_processing" {
  name = "${var.project_name}-${var.environment}-video-processing"

  visibility_timeout_seconds = 360

  message_retention_seconds = 1209600

  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_processing_dlq.arn

    maxReceiveCount = 3

    sqs_managed_sse_enabled = true
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-video-processing"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}