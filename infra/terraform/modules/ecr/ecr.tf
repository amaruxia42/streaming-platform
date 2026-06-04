resource "aws_ecr_repository" "ecr_repo" {
  name = "${var.project_name}-${var.environment}-video-api"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-video-api"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_lifecycle" {
  repository = aws_ecr_repository.ecr_repo.name

  policy = jsonencode({
    rules = [

      {
        rulePriority = 1

        description = "Keep last 10 images"

        selection = {

          tagStatus = "any"

          countType = "imageCountMoreThan"

          countNumber = 10
        }

        action = {

          type = "expire"

        }
      }
    ]
  })
}