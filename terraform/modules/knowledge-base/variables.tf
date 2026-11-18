
variable "name" {
  type        = string
  description = "Resource name prefix"
}

variable "docs_dir" {
  type        = string
  description = "Directory containing knowledge documents"
}

variable "embedding_dimensions" {
  type        = number
  default     = 384
  description = "MiniLM embedding dimensions"
}

variable "document_metadata" {
  type        = map(map(string))
  default     = {}
  description = "Metadata for knowledge documents"
}
