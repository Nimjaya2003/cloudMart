variable "name" {
  type = string
}

variable "db_subnet_ids" {
  type = list(string)
}

variable "db_sg_id" {
  type = string
}

variable "db_name" {
  type    = string
  default = "cloudmart"
}

variable "db_username" {
  type    = string
  default = "cloudmart"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  type        = bool
  default     = false
  description = "Standby replica in a second AZ. Doubles the cost, so off for dev."
}