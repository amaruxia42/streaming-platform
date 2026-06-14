resource "aws_ecs_cluster" "ecs_cluster" {
  name = "${var.project_name}-${var.environment}-ecs-cluster"

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-cluster"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecs_service" "ecs_service" {
  name            = "${var.project_name}-${var.environment}-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = var.task_definition_arn

  desired_count = var.desired_count
  launch_type   = "FARGATE"

  network_configuration {
    subnets         = var.app_subnet_ids
    security_groups = [var.ecs_service_sg_id]

    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn

    container_name = var.container_name
    container_port = var.container_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  depends_on = [
    var.listener_arn
  ]

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-service"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

