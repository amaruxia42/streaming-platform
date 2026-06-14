data "archive_file" "lambda" {
  type = "zip"

  source_file = "${path.module}/lambda_function.py"

  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "video_processor" {
  description = "Consumes video processing jobs and launches ECS transcoding tasks"

  function_name = "${var.project_name}-${var.environment}-video-processor"

  filename = data.archive_file.lambda.output_path

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.12"

  handler = "lambda_function.lambda_handler"

  role = var.lambda_role_arn

  timeout = 60

  reserved_concurrent_executions = 5

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-video-processor"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_event_source_mapping" "video_processing" {

  event_source_arn = var.video_processing_queue_arn

  function_name = aws_lambda_function.video_processor.arn

  batch_size = 1
  function_response_types = [
    "ReportBatchItemFailures"
  ]
}

resource "aws_cloudwatch_log_group" "video_processor" {

  name = "/aws/lambda/${aws_lambda_function.video_processor.function_name}"

  retention_in_days = 14
}