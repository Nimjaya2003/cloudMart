variable "name" {
  type        = string
  description = "Environment prefix, e.g. cloudmart-dev"
}

variable "notification_email" {
  type        = string
  description = "Address that receives order notifications and alarms"
}