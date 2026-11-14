variable "name" {
  type        = string
  description = "Prefix for resource names, e.g. cloudmart-dev"
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "default_service" {
  type        = string
  default     = "frontend"
  description = "Service that receives every request no other rule matches"
}

variable "services" {
  type = map(object({
    health_path   = string
    path_patterns = optional(list(string), [])
    priority      = optional(number)
  }))
  description = "One entry per service: its health check path, and for non-default services the URL paths and rule priority"
}