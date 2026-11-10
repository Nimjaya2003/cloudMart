variable "name" {
  type        = string
  description = "Environment prefix, e.g. cloudmart-dev"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository as OWNER/REPO, exactly as in the URL (case-sensitive)"

  validation {
    condition     = length(split("/", var.github_repo)) == 2
    error_message = "github_repo must look like OWNER/REPO, for example Nimjaya2003/cloudMart."
  }
}

variable "github_owner_id" {
  type        = string
  description = "GitHub repository owner numeric ID from the GitHub API"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be the numeric owner ID (digits only)."
  }
}

variable "github_repo_id" {
  type        = string
  description = "GitHub repository numeric ID from the GitHub API"

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repo_id))
    error_message = "github_repo_id must be the numeric repository ID (digits only)."
  }
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