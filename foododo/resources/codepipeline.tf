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

# resource "aws_codestarconnections_connection" "github" {
#   name          = "personal-github"
#   provider_type = "GitHub"
# }

resource "aws_codepipeline" "pipeline" {
  name       = "foododo-terrafrom-pipeline"
  role_arn   = aws_iam_role.pipeline.arn
  depends_on = [aws_eks_cluster.foododo]

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
    name = "Deploy"

    action {
      name             = "Deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["deploy_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.k8s.name
      }
    }
  }
}

# Build and deploy to ECR as a container
resource "aws_codebuild_project" "foododo" {
  name          = "foododo-terraform-build-deploy-ECR"
  description   = "foododo-terraform-build-deploy-ECR"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = "5"

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec/buildspec_codebuild.yaml")
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
  name          = "foododo-terraform-build-deploy-EKS"
  description   = "foododo-terraform-build-deploy-EKS"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = "5"

  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec/buildspec_eks.yaml")
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

# Codepipieline roles
resource "aws_iam_role" "pipeline" {
  name = "aws_iam_role_pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "codepipeline.amazonaws.com",
            "codebuild.amazonaws.com"
          ]
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

resource "aws_iam_role_policy" "codepipeline_kubectl_policy" {
  name = "aws_iam_role_policy_codepipeline_kubectl_policy"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "eks:DescribeCluster"
        ],
        Resource = "*",
        Effect   = "Allow"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "pipeline" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeStarFullAccess"
  role       = aws_iam_role.pipeline.name
}

# Codebuild EKS roles
resource "aws_iam_role" "codebuild" {
  name = "aws_iam_role_codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "codepipeline.amazonaws.com",
            "codebuild.amazonaws.com"
          ],
          AWS : "arn:aws:iam::${var.AWS_ACCOUNT_ID}:root"
        }
      },
    ]
  })
}


resource "aws_iam_role_policy" "codebuild" {
  name = "aws_iam_role_policy_codebuild"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "eks:*",
          "sts:AssumeRole"
        ],
        "Resource" : "*"
      }
    ]
  })
}


# Users
resource "aws_iam_user" "codepipeline_eks_temp" {
  name = "aws_iam_user_codepipeline_eks_temp"
  path = "/system/"
}

resource "aws_iam_user_policy" "temp" {
  name = "aws_iam_user_policy_temp"
  user = aws_iam_user.codepipeline_eks_temp.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "sts:AssumeRole"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
    ]
  })
}
