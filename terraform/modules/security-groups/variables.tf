variable "name" {
  type        = string
  description = "Prefix for resource names, e.g. cloudmart-dev"
}

variable "vpc_id" {
  type = string
}

variable "app_port" {
  type        = number
  description = "Port the backend container listens on"
  default     = 8080
}

variable "db_port" {
  type        = number
  description = "Database port (5432 for PostgreSQL, 3306 for MySQL)"
  default     = 5432
}