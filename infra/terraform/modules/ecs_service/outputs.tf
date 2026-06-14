output "ecs_cluster_name" {
  description = "ECS cluster name"

  value = aws_ecs_cluster.ecs_cluster.name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"

  value = aws_ecs_cluster.ecs_cluster.arn
}

output "ecs_service_name" {
  description = "ECS service name"

  value = aws_ecs_service.ecs_service.name
}

output "ecs_service_arn" {
  description = "ECS service ARN"

  value = aws_ecs_service.ecs_service.arn
}

