output "github_actions_role_arn" {
  description = "ARN of GitHub Actions role"
  value       = module.iam.github_actions_role_arn
}

output "repository_url" {
  description = "ECR repository URL"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  description = "ecs cluster name"
  value       = module.ecs.ecs_cluster_name
}

output "ecs_service_name" {
  description = "ecs service name"
  value       = module.ecs.ecs_service_name
}

output "ingest_bucket_name" {
  value = module.s3.ingest_bucket_name
}

output "delivery_bucket_name" {
  value = module.s3.delivery_bucket_name
}

output "assets_bucket_name" {
  value = module.s3.assets_bucket_name
}