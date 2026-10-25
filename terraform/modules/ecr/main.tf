resource "aws_ecr_repository" "this" {
  for_each = toset(var.repositories)

  name                 = "${var.name}/${each.key}"
  image_tag_mutability = "IMMUTABLE" # a tag can never be overwritten
  force_delete         = true        # dev only: lets terraform destroy remove repos that contain images

  image_scanning_configuration {
    scan_on_push = true # scans every pushed image for known vulnerabilities
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keep storage small: expire everything beyond the 10 most recent images
resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep the last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}