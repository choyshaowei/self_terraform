# ECR
resource "aws_ecr_repository" "foododo" {
  name                 = "foododo-terraform"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_ecr_lifecycle_policy" "foododo" {
  repository = aws_ecr_repository.foododo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

