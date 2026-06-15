resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role = aws_iam_role.ecs_task_execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        data.aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  description = "GitHub Actions OIDC deployment role"
  name        = "${var.project_name}-${var.environment}-github-actions-role"

  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = {
    Name        = "${var.project_name}-${var.environment}-github-actions-role"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_iam_policy_document" "github_ecr" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_ecr" {
  name = "${var.project_name}-${var.environment}-github-ecr-policy"

  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_ecr.json
}

data "aws_iam_policy_document" "github_ecs" {

  statement {
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_ecs" {

  name = "${var.project_name}-${var.environment}-github-ecs-policy"

  role = aws_iam_role.github_actions.id

  policy = data.aws_iam_policy_document.github_ecs.json
}

data "aws_iam_policy_document" "sns_to_sqs" {

  statement {

    effect = "Allow"

    principals {
      type = "Service"

      identifiers = [
        "sns.amazonaws.com"
      ]
    }

    actions = [
      "sqs:SendMessage"
    ]

    resources = [
      var.video_processing_queue_arn
    ]

    condition {
      test = "ArnEquals"

      variable = "aws:SourceArn"

      values = [
        var.video_uploaded_topic_arn
      ]
    }
  }
}

resource "aws_sqs_queue_policy" "video_processing" {

  queue_url = var.video_processing_queue_url

  policy = data.aws_iam_policy_document.sns_to_sqs.json
}

data "aws_iam_policy_document" "lambda_assume_role" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "video_processor_lambda" {

  name = "${var.project_name}-${var.environment}-video-processor-lambda-role"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {

  role = aws_iam_role.video_processor_lambda.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_ecs_runtask" {

  statement {

    actions = [
      "ecs:RunTask"
    ]

    resources = [
      "*"
    ]
  }

  statement {

    actions = [
      "iam:PassRole"
    ]

    resources = [
      aws_iam_role.transcoder_task_execution_role.arn,
      aws_iam_role.transcoder_task_role.arn
    ]

    condition {

      test = "StringEquals"

      variable = "iam:PassedToService"

      values = [

        "ecs-tasks.amazonaws.com"

      ]

    }
  }
}

resource "aws_iam_role_policy" "lambda_ecs_runtask" {

  name = "${var.project_name}-${var.environment}-lambda-ecs-runtask"

  role = aws_iam_role.video_processor_lambda.id

  policy = data.aws_iam_policy_document.lambda_ecs_runtask.json
}

resource "aws_iam_role" "transcoder_task_execution_role" {

  name = "${var.project_name}-${var.environment}-transcoder-task-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

data "aws_iam_policy_document" "transcoder_task_role" {

  statement {

    sid = "ReadFromIngestBucket"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${var.ingest_bucket_arn}/*"
    ]
  }

  statement {

    sid = "WriteToDeliveryBucket"

    actions = [
      "s3:PutObject"
    ]

    resources = [
      "${var.delivery_bucket_arn}/*"
    ]
  }
}

data "aws_iam_policy_document" "ecs_task_assume_role" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {

      type = "Service"

      identifiers = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "transcoder_task_execution_policy" {

  role = aws_iam_role.transcoder_task_execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "transcoder_task_role" {

  name = "${var.project_name}-${var.environment}-transcoder-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

resource "aws_iam_role_policy" "transcoder_s3" {

  name = "${var.project_name}-${var.environment}-transcoder-s3-policy"

  role = aws_iam_role.transcoder_task_role.id

  policy = data.aws_iam_policy_document.transcoder_task_role.json
}