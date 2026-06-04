output "ecs_log_group_name" {
  description = "CloudWatch ECS log group name"

  value = aws_cloudwatch_log_group.ecs_log_group.name
}

output "ecs_log_group_arn" {
  description = "CloudWatch ECS log group ARN"

  value = aws_cloudwatch_log_group.ecs_log_group.arn
}