output "transcoder_task_definition_arn" {
  value = aws_ecs_task_definition.transcoder.arn
}

output "transcoder_task_definition_family" {
  value = aws_ecs_task_definition.transcoder.family
}