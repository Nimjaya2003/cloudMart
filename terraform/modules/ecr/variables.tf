variable "name" {
  type        = string
  description = "Project prefix, e.g. cloudmart"
}

variable "repositories" {
  type        = list(string)
  description = "Repository names to create, e.g. [\"frontend\", \"backend\"]"
}