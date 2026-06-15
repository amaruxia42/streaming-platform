output "ecs_task_execution_role_arn" {
  description = "ARN of ECS task execution role"

  value = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_execution_role_name" {
  description = "Name of ECS task execution role"

  value = aws_iam_role.ecs_task_execution_role.name
}

output "ecs_task_role_arn" {
  description = "ARN of ECS task role"

  value = aws_iam_role.ecs_task_role.arn
}

output "ecs_task_role_name" {
  description = "Name of ECS task role"

  value = aws_iam_role.ecs_task_role.name
}

output "github_actions_role_arn" {
  description = "ARN of GitHub Actions role"
  value       = aws_iam_role.github_actions.arn
}

output "video_processor_lambda_role_arn" {
  value = aws_iam_role.video_processor_lambda.arn
}

output "transcoder_task_execution_role_arn" {
  description = "Transcoder execution role ARN"

  value = aws_iam_role.transcoder_task_execution_role.arn
}

output "transcoder_task_execution_role_name" {
  description = "Transcoder execution role name"

  value = aws_iam_role.transcoder_task_execution_role.name
}

output "transcoder_task_role_arn" {
  description = "Transcoder task role ARN"

  value = aws_iam_role.transcoder_task_role.arn
}

output "transcoder_task_role_name" {
  description = "Transcoder task role name"

  value = aws_iam_role.transcoder_task_role.name
}

output "video_processor_lambda_role_name" {
  description = "Video processor lambda role name"

  value = aws_iam_role.video_processor_lambda.name
}