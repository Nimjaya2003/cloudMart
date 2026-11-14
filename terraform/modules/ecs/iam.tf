data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ---------- Execution role (shared): used by ECS to START tasks ----------
resource "aws_iam_role" "execution" {
  name               = "${var.name}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "read_db_secret" {
  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "execution_secret" {
  name   = "read-db-secret"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.read_db_secret.json
}

# ---------- Task role (one per service): used by the app code itself ----------
resource "aws_iam_role" "task" {
  for_each = var.services

  name               = "${var.name}-${each.key}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json
}

# Only services listed in task_policies get any permissions
resource "aws_iam_role_policy" "task" {
  for_each = var.task_policies

  name   = "service-access"
  role   = aws_iam_role.task[each.key].id
  policy = each.value
}