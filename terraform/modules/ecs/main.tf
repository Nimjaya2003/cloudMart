data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
}

# ---------- Log groups (container stdout/stderr land here) ----------
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/${var.name}/frontend"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.name}/backend"
  retention_in_days = var.log_retention_days
}

# ======================== BACKEND ========================
resource "aws_ecs_task_definition" "backend" {
  family                   = "${var.name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "backend"
    image     = var.backend_image
    essential = true

    portMappings = [{
      containerPort = var.app_port
      protocol      = "tcp"
    }]

    # Plain, non-sensitive settings
    environment = [
      { name = "DB_HOST", value = var.db_address },
      { name = "DB_PORT", value = tostring(var.db_port) },
      { name = "DB_NAME", value = var.db_name },
    ]

    # Sensitive values: ECS fetches these from Secrets Manager at start-up.
    # The "...:username::" suffix selects one key from the secret's JSON.
    secrets = [
      { name = "DB_USER", valueFrom = "${var.db_secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "backend"
      }
    }
  }])
}

resource "aws_ecs_service" "backend" {
  name            = "${var.name}-backend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 60 # don't judge a task unhealthy while it's still starting

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.app_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.backend_tg_arn
    container_name   = "backend"
    container_port   = var.app_port
  }

  # If a new deployment keeps failing, stop it and roll back automatically
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    # Auto scaling owns the task count, and CI/CD (next phase) will own the image version
    ignore_changes = [desired_count, task_definition]
  }
}

# ======================== FRONTEND ========================
resource "aws_ecs_task_definition" "frontend" {
  family                   = "${var.name}-frontend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = "frontend"
    image     = var.frontend_image
    essential = true

    portMappings = [{
      containerPort = var.app_port
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "frontend"
      }
    }
  }])
}

resource "aws_ecs_service" "frontend" {
  name            = "${var.name}-frontend"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 30

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.app_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.frontend_tg_arn
    container_name   = "frontend"
    container_port   = var.app_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count, task_definition]
  }
}