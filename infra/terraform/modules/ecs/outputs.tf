output "ecs_cluster_name" {
  description = "ecs cluster name"
  value       = aws_ecs_cluster.ecs_cluster.name
}

output "ecs_cluster_arn" {
  description = "ecs cluster arn"
  value       = aws_ecs_cluster.ecs_cluster.arn
}

output "ecs_service_name" {
  description = "ecs service name"
  value       = aws_ecs_service.ecs_service.name
}

output "ecs_service_arn" {
  description = "ecs service arn"
  value       = aws_ecs_service.ecs_service.id
}