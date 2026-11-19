
# =============================================
# 1. Agent ECR repository
# =============================================

resource "aws_ecr_repository" "agent" {

  name                 = "cloudmart/agent"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}


# =============================================
# 2. Groq API key secret
# =============================================

resource "aws_secretsmanager_secret" "groq" {

  name        = "cloudmart/dev/groq-api-key"
  description = "External LLM API key for CloudMart agent"

  recovery_window_in_days = 7
}


# =============================================
# 3. Outputs
# =============================================

output "agent_ecr_url" {

  value = aws_ecr_repository.agent.repository_url
}


output "groq_secret_arn" {

  value = aws_secretsmanager_secret.groq.arn
}
