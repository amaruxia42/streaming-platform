output "video_processing_queue_name" {
  value = aws_sqs_queue.video_processing.name
}

output "video_processing_queue_url" {
  value = aws_sqs_queue.video_processing.url
}

output "video_processing_queue_arn" {
  value = aws_sqs_queue.video_processing.arn
}

output "video_processing_dlq_arn" {
  value = aws_sqs_queue.video_processing_dlq.arn
}