# CodePipeline
resource "aws_s3_bucket" "foododo" {
  bucket        = "foododo"
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "foododo" {
  bucket = aws_s3_bucket.foododo.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
resource "aws_s3_bucket_acl" "example" {
  depends_on = [aws_s3_bucket_ownership_controls.foododo]
  bucket     = aws_s3_bucket.foododo.id
  acl        = "private"
}

resource "aws_codestarconnections_connection" "example" {
  name          = "personal-github"
  provider_type = "GitHub"
}

resource "aws_codepipeline" "pipeline" {
  name     = "foododo-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.foododo.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.example.arn
        FullRepositoryId = "choyshaowei/foododo_landing"
        BranchName       = "master"
      }
    }
  }
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.foododo.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        BucketName = aws_s3_bucket.foododo.bucket
        Extract    = "true"
      }
    }
  }
}

# Build and deploy to ECR as a container
resource "aws_codebuild_project" "foododo" {
  name          = "foododo"
  description   = "foododo"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = "5"

  source {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    dynamic "environment_variable" {
      for_each = var.env_vars
      content {
        name  = environment_variable.key
        value = environment_variable.value
      }
    }
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}

resource "aws_iam_role" "pipeline" {
  name = "aws_iam_role_pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_role_policy" "pipeline" {
  name = "aws_iam_role_policy_pipeline"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "codebuild:StartBuild"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
resource "aws_iam_role" "codebuild" {
  name = "aws_iam_role_codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "sts:AssumeRole",
          "s3:GetObject",
          "s3:PutObject",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}
resource "aws_iam_role_policy" "codebuild" {
  name = "aws_iam_role_policy_codebuild"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# ECR
module "ecr" {
  source          = "terraform-aws-modules/ecr/aws"
  repository_name = "foododo"

  repository_read_write_access_arns = ["arn:aws:iam::012345678901:role/terraform"]
  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1,
        description  = "Keep last 5 images",
        selection = {
          tagStatus     = "tagged",
          tagPrefixList = ["v"],
          countType     = "imageCountMoreThan",
          countNumber   = 5

        },
        action = {
          type = "expire"
        }
      }
    ]
  })

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

