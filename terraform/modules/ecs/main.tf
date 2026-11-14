data "aws_region" "current" {}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
}

# ---------- Service discovery: private DNS like catalog.cloudmart.local ----------
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = var.namespace_name
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "this" {
  for_each = { for k, v in var.services : k => v if v.discovery }

  name = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ---------- One log group, task definition and service per entry ----------
resource "aws_cloudwatch_log_group" "this" {
  for_each = var.services

  name              = "/ecs/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "this" {
  for_each = var.services

  family                   = "${var.name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task[each.key].arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([{
    name      = each.key
    image     = each.value.image
    essential = true

    portMappings = [{
      containerPort = var.app_port
      protocol      = "tcp"
    }]

    environment = [for k, v in each.value.environment : { name = k, value = v }]
    secrets     = [for k, v in each.value.secrets : { name = k, valueFrom = v }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.this[each.key].name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = each.key
      }
    }
  }])
}

resource "aws_ecs_service" "this" {
  for_each = var.services

  name            = "${var.name}-${each.key}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.app_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = each.value.target_group_arn
    container_name   = each.key
    container_port   = var.app_port
  }

  # Only services with discovery = true get a DNS name
  dynamic "service_registries" {
    for_each = each.value.discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.this[each.key].arn
    }
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    # Auto scaling owns the task count and the CI/CD pipeline owns the image version
    ignore_changes = [desired_count, task_definition]
  }
}