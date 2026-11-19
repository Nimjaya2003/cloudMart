
# =============================================
# 1. CloudWatch logging
# =============================================

resource "aws_cloudwatch_log_group" "agent_ecs" {
  name              = "/ecs/${local.agent_ecs_name}"
  retention_in_days = 7
}


# =============================================
# 2. Agent ECS task definition
# =============================================

resource "aws_ecs_task_definition" "agent" {

  family = local.agent_ecs_name

  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  cpu    = "1024"
  memory = "4096"

  execution_role_arn = aws_iam_role.agent_ecs_execution.arn

  task_role_arn = aws_iam_role.agent_ecs_task.arn


  # Match the existing ARM64 Docker image
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }


  container_definitions = jsonencode([
    {
      name = "agent"

      image = var.agent_image_uri

      essential = true

      linuxParameters = {
        initProcessEnabled = true
      }

      portMappings = [
        {
          containerPort = 8080
          protocol      = "tcp"
        }
      ]


      # Environment configuration
      environment = [
        for key, value in {
          AWS_DEFAULT_REGION = "ap-south-1"

          LLM_PROVIDER = "groq"

          LLM_MODEL_ID = var.agent_model_id

          GROQ_SECRET_ARN = aws_secretsmanager_secret.groq.arn

          GATEWAY_URL = aws_bedrockagentcore_gateway.cloudmart.gateway_url

          KB_DOCS_BUCKET = module.knowledge_base.docs_bucket

          KB_VECTOR_BUCKET = module.knowledge_base.vector_bucket

          KB_VECTOR_INDEX = module.knowledge_base.vector_index

          KB_MODEL_PATH = "/opt/minilm"

          HF_HUB_OFFLINE = "1"

          TRANSFORMERS_OFFLINE = "1"

          OMP_NUM_THREADS = "1"

          MKL_NUM_THREADS = "1"

        } : {
          name  = key
          value = value
        }
      ]


      # Container health check
      healthCheck = {

        command = [
          "CMD",
          "python",
          "-c",
          "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/ping',timeout=5).read()"
        ]

        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 90
      }


      # CloudWatch logging
      logConfiguration = {

        logDriver = "awslogs"

        options = {

          awslogs-group = aws_cloudwatch_log_group.agent_ecs.name

          awslogs-region = "ap-south-1"

          awslogs-stream-prefix = "agent"
        }
      }
    }
  ])

  tags = {
    Name    = local.agent_ecs_name
    Project = "CloudMart"
    Phase   = "10"
  }
}


# =============================================
# 3. ECS service
# =============================================

resource "aws_ecs_service" "agent" {

  name = local.agent_ecs_name

  cluster = var.agent_cluster_arn

  task_definition = aws_ecs_task_definition.agent.arn

  desired_count = var.agent_desired_count

  launch_type = "FARGATE"

  platform_version = "LATEST"


  # Development debugging and private access
  enable_execute_command = true

  wait_for_steady_state = true


  # Deployment protection
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }


  # Private application networking
  network_configuration {

    subnets = var.agent_subnet_ids

    security_groups = [
      aws_security_group.agent_ecs.id
    ]

    assign_public_ip = false
  }


  # Register each running task in Cloud Map
  service_registries {

    registry_arn = aws_service_discovery_service.agent.arn
  }


  depends_on = [
    aws_iam_role_policy_attachment.agent_ecs_execution,
    aws_iam_role_policy.agent_ecs_task,
    aws_vpc_security_group_egress_rule.agent_outbound,
    aws_vpc_security_group_ingress_rule.agent_from_app
  ]

  tags = {
    Name    = local.agent_ecs_name
    Project = "CloudMart"
  }
}


# =============================================
# 4. Outputs
# =============================================

output "agent_ecs_cluster_arn" {
  value = var.agent_cluster_arn
}

output "agent_ecs_service_name" {
  value = aws_ecs_service.agent.name
}

output "agent_ecs_task_definition_arn" {
  value = aws_ecs_task_definition.agent.arn
}

output "agent_ecs_task_role_arn" {
  value = aws_iam_role.agent_ecs_task.arn
}

output "agent_ecs_security_group_id" {
  value = aws_security_group.agent_ecs.id
}

output "agent_ecs_log_group" {
  value = aws_cloudwatch_log_group.agent_ecs.name
}

output "agent_internal_url" {
  value = "http://${aws_service_discovery_service.agent.name}.${aws_service_discovery_private_dns_namespace.agent.name}:8080"
}
