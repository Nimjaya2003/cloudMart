variable "name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "app_sg_id" {
  type = string
}

variable "frontend_image" {
  type        = string
  description = "Full image URI with tag"
}

variable "backend_image" {
  type        = string
  description = "Full image URI with tag"
}

variable "frontend_tg_arn" {
  type = string
}

variable "backend_tg_arn" {
  type = string
}

variable "db_address" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
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

variable "cpu" {
  type    = number
  default = 256 # 0.25 vCPU, the smallest Fargate size
}

variable "memory" {
  type    = number
  default = 512 # 0.5 GB
}

variable "desired_count" {
  type    = number
  default = 2 # one task per AZ
}

variable "min_capacity" {
  type    = number
  default = 2
}

variable "max_capacity" {
  type    = number
  default = 4
}

variable "cpu_target" {
  type        = number
  default     = 60
  description = "Average CPU % that auto scaling tries to maintain"
}

variable "log_retention_days" {
  type    = number
  default = 7
}