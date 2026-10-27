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