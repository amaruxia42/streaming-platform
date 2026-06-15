module "vpc" {
  source = "../../modules/vpc"

  environment  = var.environment
  project_name = var.project_name

  aws_region          = var.aws_region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidrs = var.public_subnet_cidrs
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
  public_subnet_ids = module.vpc.public_subnet_ids

  alb_sg_id = module.sec_grp.alb_sg_id
}

module "iam" {
  source = "../../modules/iam"

  environment  = var.environment
  project_name = var.project_name

  github_repository = var.github_repository

  video_uploaded_topic_arn   = module.sns.video_uploaded_topic_arn
  video_processing_queue_arn = module.sqs.video_processing_queue_arn
  video_processing_queue_url = module.sqs.video_processing_queue_url

  transcoder_task_definition_arn = module.ecs_task_transcoder.transcoder_task_definition_arn

  delivery_bucket_arn = module.s3.delivery_bucket_arn
  ingest_bucket_arn   = module.s3.ingest_bucket_arn
}

module "ecs_service" {
  source = "../../modules/ecs_service"

  project_name   = var.project_name
  environment    = var.environment
  container_name = var.container_name

  app_subnet_ids    = module.vpc.app_subnet_ids
  ecs_service_sg_id = module.sec_grp.ecs_service_sg_id

  target_group_arn = module.alb.target_group_arn
  listener_arn     = module.alb.listener_arn

  task_definition_arn = module.ecs_task_video_service.task_definition_arn
}

module "ecs_task_transcoder" {
  source = "../../modules/ecs_task_transcoder"

  project_name = var.project_name
  environment  = var.environment

  aws_region = var.aws_region

  container_image = "${module.ecr.repository_url}:latest"

  execution_role_arn = module.iam.transcoder_task_execution_role_arn

  task_role_arn = module.iam.transcoder_task_role_arn

  log_group_name = module.cloudwatch.ecs_log_group_name
}

module "ecs_task_video_service" {
  source = "../../modules/ecs_task_video_service"

  project_name = var.project_name
  environment  = var.environment

  aws_region = var.aws_region

  container_image = "nginx:alpine"

  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn

  log_group_name = module.cloudwatch.ecs_log_group_name
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

module "sqs" {
  source = "../../modules/sqs"

  project_name = var.project_name
  environment  = var.environment
}

module "sns" {
  source = "../../modules/sns"

  project_name = var.project_name
  environment  = var.environment

  video_processing_queue_arn = module.sqs.video_processing_queue_arn
}

module "lambda" {
  source = "../../modules/lambda"

  project_name = var.project_name
  environment  = var.environment

  lambda_role_arn = module.iam.video_processor_lambda_role_arn

  video_processing_queue_arn = module.sqs.video_processing_queue_arn

  ecs_cluster_name               = module.ecs_service.ecs_cluster_name
  transcoder_task_definition_arn = module.ecs_task_transcoder.transcoder_task_definition_arn
}
