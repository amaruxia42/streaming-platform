output "task_definition_arn" {
  value = aws_ecs_task_definition.video_service.arn
}

output "task_definition_family" {
  value = aws_ecs_task_definition.video_service.family
}