resource "aws_ecs_task_definition" "transcoder" {

  family = "${var.project_name}-${var.environment}-transcoder"

  requires_compatibilities = [
    "FARGATE"
  ]

  network_mode = "awsvpc"

  cpu    = var.cpu
  memory = var.memory

  execution_role_arn = var.execution_role_arn

  task_role_arn = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = "transcoder"
      image     = var.container_image
      essential = true

      logConfiguration = {

        logDriver = "awslogs"

        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "transcoder"
        }
      }

      runtime_platform = {

        operating_system_family = "LINUX"
        cpu_architecture        = "X86_64"
      }

      ephemeral_storage = {
        size_in_gib = 100
      }

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-transcoder"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
