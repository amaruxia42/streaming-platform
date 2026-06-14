resource "aws_sns_topic" "video_uploaded" {
  name = "${var.project_name}-${var.environment}-video-uploaded"

  tags = {
    Name        = "${var.project_name}-${var.environment}-video-uploaded"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_sns_topic_subscription" "video_processing" {
  topic_arn = aws_sns_topic.video_uploaded.arn

  protocol = "sqs"

  endpoint = var.video_processing_queue_arn

  raw_message_delivery = true
}