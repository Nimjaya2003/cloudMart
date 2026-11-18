
data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# 1. S3 bucket for original documents
resource "aws_s3_bucket" "docs" {
  bucket        = "${var.name}-kb-docs-${local.account_id}"
  force_destroy = true
}

# 2. Encrypt the documents
resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 3. Prevent public access
resource "aws_s3_bucket_public_access_block" "docs" {
  bucket = aws_s3_bucket.docs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. Upload Markdown documents
resource "aws_s3_object" "docs" {
  for_each = fileset(var.docs_dir, "*.md")

  bucket       = aws_s3_bucket.docs.id
  key          = each.value
  source       = "${var.docs_dir}/${each.value}"
  source_hash  = filemd5("${var.docs_dir}/${each.value}")
  content_type = "text/markdown"

  depends_on = [
    aws_s3_bucket_public_access_block.docs,
    aws_s3_bucket_server_side_encryption_configuration.docs
  ]
}

# 5. Upload document metadata
resource "aws_s3_object" "metadata" {
  for_each = var.document_metadata

  bucket = aws_s3_bucket.docs.id
  key    = "${each.key}.metadata.json"

  content = jsonencode({
    metadataAttributes = each.value
  })

  content_type = "application/json"

  depends_on = [
    aws_s3_bucket_public_access_block.docs,
    aws_s3_bucket_server_side_encryption_configuration.docs
  ]
}

# 6. Create S3 Vector bucket
resource "aws_s3vectors_vector_bucket" "this" {
  vector_bucket_name = "${var.name}-kb-vectors"
  force_destroy      = true
}

# 7. Create the vector index
resource "aws_s3vectors_index" "this" {
  vector_bucket_name = aws_s3vectors_vector_bucket.this.vector_bucket_name
  index_name         = "${var.name}-kb-index"

  data_type       = "float32"
  dimension       = var.embedding_dimensions
  distance_metric = "cosine"

  metadata_configuration {
    non_filterable_metadata_keys = ["text"]
  }
}
