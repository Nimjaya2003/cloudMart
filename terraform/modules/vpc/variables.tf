variable "name" {
  type        = string
  description = "Prefix for resource names, e.g. cloudmart-dev"
}

variable "vpc_cidr" {
  type = string
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to spread subnets across"
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}