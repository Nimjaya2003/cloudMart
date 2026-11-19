
variable "agent_image_uri" {
  type        = string
  description = "ARM64 agent image stored in ECR"
}

variable "agent_model_id" {
  type        = string
  description = "External Groq generation model"
  default     = "openai/gpt-oss-20b"
}

variable "agent_cluster_arn" {
  type        = string
  description = "Existing CloudMart ECS cluster ARN"
}

variable "agent_vpc_id" {
  type        = string
  description = "Existing CloudMart VPC ID"
}

variable "agent_subnet_ids" {
  type        = list(string)
  description = "Existing private application subnet IDs"
}

variable "agent_client_security_group_ids" {
  type        = set(string)
  description = "Existing application security groups allowed to invoke the agent"
}

variable "agent_desired_count" {
  type        = number
  description = "Number of running AI agent tasks"
  default     = 1
}
