output "lambda_function_arn" {
  value = aws_lambda_function.video_processor.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.video_processor.function_name
}

output "lambda_invoke_arn" {
  value = aws_lambda_function.video_processor.invoke_arn
}