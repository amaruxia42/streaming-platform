module "vpc" {
  source = "../../modules/vpc"

  environment  = var.environment
  project_name = var.project_name

  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
  aws_region          = var.aws_region
  vpc_endpoint_sg_id  = module.sec_grp.vpc_endpoint_sg_id

  cluster_name = var.cluster_name
}

module "sec_grp" {
  source = "../../modules/sec_grps"

  environment  = var.environment
  project_name = var.project_name

  vpc_id           = module.vpc.vpc_id
  container_port   = var.container_port
  app_subnet_cidrs = module.vpc.app_subnet_cidrs
}

module "alb" {
  source = "../../modules/alb"

  environment  = var.environment
  project_name = var.project_name

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_cidrs

  alb_sg_id = module.sec_grp.alb_sg_id
}

module "iam" {
  source = "../../modules/iam"

  environment  = var.environment
  project_name = var.project_name

  github_repository = var.github_repository

}

module "ecs" {
  source = "../../modules/ecs"

  aws_region      = var.aws_region
  project_name    = var.project_name
  environment     = var.environment
  container_image = var.container_image
  container_name  = var.container_name

  app_subnet_ids    = module.vpc.app_subnet_cidrs
  ecs_service_sg_id = module.sec_grp.ecs_service_sg_id

  target_group_arn = module.alb.target_group_arn
  listener_arn     = module.alb.listener_arn

  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn

  ecs_log_group_name = module.cloudwatch.ecs_log_group_name
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  environment  = var.environment
  project_name = var.project_name

  log_retention_days = var.log_retention_days
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "github_actions" {
  source = "../../modules/github_oidc"

  project_name = var.project_name
  environment  = var.environment

  github_repository = var.github_repository
}

module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  environment  = var.environment
  project_name = var.project_name

  assets_bucket_name   = module.s3.assets_bucket_name
  delivery_bucket_name = module.s3.delivery_bucket_name
}







