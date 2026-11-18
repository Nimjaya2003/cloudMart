
output "docs_bucket" {
  value = aws_s3_bucket.docs.id
}

output "vector_bucket" {
  value = aws_s3vectors_vector_bucket.this.vector_bucket_name
}

output "vector_index" {
  value = aws_s3vectors_index.this.index_name
}
