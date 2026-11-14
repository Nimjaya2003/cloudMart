data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  repo_owner = split("/", var.github_repo)[0]
  repo_name  = split("/", var.github_repo)[1]

  # GitHub's immutable subject format: names plus permanent numeric IDs
  github_sub = "repo:${local.repo_owner}@${var.github_owner_id}/${local.repo_name}@${var.github_repo_id}:ref:refs/heads/${var.branch}"
}

# --- AWS learns to trust tokens issued by GitHub Actions ---
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]

  # AWS no longer validates this for GitHub, but older provider versions require the field
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# --- Trust policy: WHO may assume the role ---
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only THIS repo (pinned by permanent IDs), only THIS branch
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.github_sub]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.name}-github-actions-role"
  assume_role_policy = data.aws_iam_policy_document.trust.json
}

# --- Permissions policy: WHAT the role may do (just enough to deploy) ---
data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"] # this action cannot be limited to a resource
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage", # lets Docker check whether a manifest exists (the HEAD request)
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = ["arn:aws:ecr:${local.region}:${local.account_id}:repository/${var.project}/*"]
  }

  statement {
    sid       = "EcsTaskDefinitions"
    actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
    resources = ["*"] # these actions do not support resource-level limits
  }

  statement {
    sid       = "EcsDeploy"
    actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
    resources = ["arn:aws:ecs:${local.region}:${local.account_id}:service/${var.name}-cluster/*"]
  }

  statement {
    sid       = "ReadLoadBalancerAddress"
    actions   = ["elasticloadbalancing:DescribeLoadBalancers"]
    resources = ["*"] # describe actions cannot be limited to one resource
  }

  # The new task definition references our ECS roles, so the pipeline must be allowed to
  # "pass" them, and only to the ECS tasks service
  statement {
    sid     = "PassEcsRoles"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.name}-ecs-execution-role",
      "arn:aws:iam::${local.account_id}:role/${var.name}-*-task-role",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-to-ecs"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deploy.json
}