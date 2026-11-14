variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager secret holding the DB username and password"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "namespace_name" {
  type        = string
  default     = "cloudmart.local"
  description = "Private DNS domain for service discovery"
}

variable "cpu_target" {
  type    = number
  default = 60
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "services" {
  type = map(object({
    image            = string
    target_group_arn = string
    cpu              = optional(number, 256)
    memory           = optional(number, 512)
    desired_count    = optional(number, 1)
    min_capacity     = optional(number, 1)
    max_capacity     = optional(number, 3)
    environment      = optional(map(string), {})
    secrets          = optional(map(string), {}) # ENV_NAME => Secrets Manager valueFrom
    discovery        = optional(bool, false)     # register a private DNS name
  }))
}

variable "task_policies" {
  type        = map(string)
  default     = {}
  description = "Service name => IAM policy JSON for that service's task role"
}