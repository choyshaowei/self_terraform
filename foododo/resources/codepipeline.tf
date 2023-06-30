# CodePipeline
resource "aws_s3_bucket" "foododo" {
  bucket        = "foododo-terraform"
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

resource "aws_codestarconnections_connection" "github" {
  name          = "personal-github"
  provider_type = "GitHub"
}
resource "aws_codepipeline" "pipeline" {
  name     = "foododo-terrafrom-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.foododo.bucket
    type     = "S3"
  }
  #  Source using codestar connection
  # stage {
  #   name = "Source"
  #   action {
  #     name             = "Source"
  #     category         = "Source"
  #     owner            = "AWS"
  #     provider         = "CodeStarSourceConnection"
  #     version          = "1"
  #     output_artifacts = ["source_output"]
  #     configuration = {
  #       ConnectionArn    = aws_codestarconnections_connection.github.arn
  #       FullRepositoryId = "choyshaowei/foododo_landing"
  #       BranchName       = "master"
  #     }
  #   }
  # }
  #  Source using github connection
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        Owner                = "choyshaowei"
        Repo                 = "foododo_landing"
        Branch               = "master"
        OAuthToken           = var.GITHUB_TOKEN
        PollForSourceChanges = true
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
      output_artifacts = ["build_output", "image_definitions"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.foododo.name
      }
    }
  }

  stage {
    name = "Deploy to K8s cluster"

    action {
      name             = "Deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output", "image_definitions"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.k8s.name
      }
    }
  }

  # stage {
  #   name = "Deploy"
  #   action {
  #     name            = "Deploy"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "ECS"
  #     input_artifacts = ["build_output"]
  #     version         = "1"
  #     configuration = {
  #       ClusterName = aws_ecs_cluster.ecs_cluster.name
  #       ServiceName = aws_ecs_service.foododo_terraform_landing_fargate_service.name
  #       FileName    = "image_definitions.json"
  #     }
  #   }
  # }

}

# Build and deploy to ECR as a container
resource "aws_codebuild_project" "foododo" {
  name          = "foododo-terraform"
  description   = "foododo-terraform"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = "5"

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec/buildspec.yaml")
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    dynamic "environment_variable" {
      for_each = local.CODEBUILD_ENV_VARS
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

# Deploy to k8s
resource "aws_codebuild_project" "k8s" {
  name          = "foododo-terraform"
  description   = "foododo-terraform"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = "5"

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec/buildspec_k8s.yaml")
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }

  dynamic "environment_variable" {
    for_each = local.CODEBUILD_ENV_VARS
    content {
      name  = environment_variable.key
      value = environment_variable.value
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
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

# Attach necessary policies to CodePipeline IAM role
resource "aws_iam_role_policy_attachment" "pipeline" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeStarFullAccess"
  role       = aws_iam_role.pipeline.name
}
resource "aws_iam_role" "codebuild" {
  name = "aws_iam_role_codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role" "ecr_role" {
  name = "ecrRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}


# ECR
resource "aws_iam_role_policy" "ecr_policy" {
  name = "ecrPolicy"
  role = aws_iam_role.ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Effect   = "Allow"
        Resource = "*"
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
          "logs:PutLogEvents",
          "ecr:GetAuthorizationToken",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecs:UpdateService",
        ],
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
