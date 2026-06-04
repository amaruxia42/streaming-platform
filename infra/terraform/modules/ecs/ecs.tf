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
  task_definition = aws_ecs_task_definition.ecs_task.arn

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

  health_check_grace_period_seconds = 60

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

resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "${var.project_name}-${var.environment}-task"
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  cpu                = var.cpu
  memory             = var.memory
  execution_role_arn = var.execution_role_arn
  task_role_arn      = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = var.container_name
      image = var.container_image

      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = var.ecs_log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project_name}-${var.environment}-ecs-task"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

