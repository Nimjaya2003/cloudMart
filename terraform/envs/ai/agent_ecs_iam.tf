
# =============================================
# 1. Account information
# =============================================

data "aws_caller_identity" "agent_ecs_account" {}

locals {
  agent_ecs_name = "cloudmart-dev-agent"

  agent_ecs_account_id = data.aws_caller_identity.agent_ecs_account.account_id

  agent_vector_index_arn = "arn:aws:s3vectors:ap-south-1:${local.agent_ecs_account_id}:bucket/${module.knowledge_base.vector_bucket}/index/${module.knowledge_base.vector_index}"
}


# =============================================
# 2. Trust policy for ECS tasks
# =============================================

data "aws_iam_policy_document" "agent_ecs_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.agent_ecs_account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"

      values = [
        "arn:aws:ecs:ap-south-1:${local.agent_ecs_account_id}:*"
      ]
    }
  }
}


# =============================================
# 3. ECS task execution role
# =============================================

resource "aws_iam_role" "agent_ecs_execution" {
  name = "${local.agent_ecs_name}-execution-role"

  assume_role_policy = data.aws_iam_policy_document.agent_ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "agent_ecs_execution" {
  role = aws_iam_role.agent_ecs_execution.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# =============================================
# 4. ECS application task role
# =============================================

resource "aws_iam_role" "agent_ecs_task" {
  name = "${local.agent_ecs_name}-task-role"

  assume_role_policy = data.aws_iam_policy_document.agent_ecs_assume.json
}


# =============================================
# 5. Agent application permissions
# =============================================

data "aws_iam_policy_document" "agent_ecs_task" {

  # Retrieve the external LLM API key
  statement {
    sid    = "ReadGroqSecret"
    effect = "Allow"

    actions = [
      "secretsmanager:GetSecretValue"
    ]

    resources = [
      aws_secretsmanager_secret.groq.arn
    ]
  }

  # Invoke existing CloudMart Gateway
  statement {
    sid    = "InvokeCloudMartGateway"
    effect = "Allow"

    actions = [
      "bedrock-agentcore:InvokeGateway"
    ]

    resources = [
      aws_bedrockagentcore_gateway.cloudmart.gateway_arn
    ]
  }

  # Retrieve relevant knowledge vectors
  statement {
    sid    = "QueryKnowledgeVectors"
    effect = "Allow"

    actions = [
      "s3vectors:QueryVectors",
      "s3vectors:GetVectors"
    ]

    resources = [
      local.agent_vector_index_arn
    ]
  }

  # Enable secure development access through ECS Exec
  statement {
    sid    = "ECSExecChannels"
    effect = "Allow"

    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]

    resources = ["*"]
  }
}


resource "aws_iam_role_policy" "agent_ecs_task" {
  name = "${local.agent_ecs_name}-task-access"

  role = aws_iam_role.agent_ecs_task.id

  policy = data.aws_iam_policy_document.agent_ecs_task.json
}
