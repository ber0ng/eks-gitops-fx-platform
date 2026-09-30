resource "aws_ecr_repository" "ecr_repository" {
  for_each = toset(var.repository_name)
  name     = each.value

  force_delete         = var.force_delete
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

}

resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy" {
  for_each   = aws_ecr_repository.ecr_repository
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${var.keep_last_images} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.keep_last_images
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
