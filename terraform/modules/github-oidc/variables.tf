variable "name" {
  type        = string
  description = "Environment prefix, e.g. cloudmart-dev"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository as OWNER/REPO, exactly as in the URL (case-sensitive)"
}

variable "github_owner_id" {
  type        = string
  description = "GitHub repository owner numeric ID from the GitHub API"
}

variable "github_repo_id" {
  type        = string
  description = "GitHub repository numeric ID from the GitHub API"
}

variable "branch" {
  type        = string
  default     = "main"
  description = "Only workflows running on this branch may assume the role"
}

variable "project" {
  type        = string
  default     = "cloudmart"
  description = "ECR repository prefix, i.e. repositories named <project>/*"
}