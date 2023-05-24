variable "AWS_REGION" {
  description = "aws-region"
  default     = "ap-southeast-1"
  type        = string
}
variable "AWS_ACCESS_KEY_ID" {
  description = "aws-key"
  type        = string
  sensitive   = true
  default     = ""
}
variable "AWS_SECRET_ACCESS_KEY" {
  description = "aws-secret"
  type        = string
  sensitive   = true
  default     = ""
}
variable "GITHUB_TOKEN" {
  description = "github-token"
  type        = string
  sensitive   = true
  default     = ""
}
provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Create an internet gateway and attach it to the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
}

# Create a NAT gateway for the private subnet
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
}

# Setup route tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

# CodePipeline
resource "aws_s3_bucket" "bucket" {
  bucket        = "foododo-landing"
  acl           = "private" // or any other default acl
  force_destroy = true
}

resource "aws_codepipeline" "pipeline" {
  name     = "foododo-landing-pipeline"
  role_arn = aws_iam_role.pipeline.arn

  artifact_store {
    location = aws_s3_bucket.bucket.bucket
    type     = "S3"
  }

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
        Owner      = "choyshaowei"
        Repo       = "foododo_landing"
        Branch     = "master"
        OAuthToken = var.GITHUB_TOKEN
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
        ProjectName = aws_codebuild_project.foododo_landing.name
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
        BucketName = aws_s3_bucket.bucket.bucket
        Extract    = "true"
      }
    }
  }
}

resource "aws_codebuild_project" "foododo_landing" {
  name          = "foododo_landing"
  description   = "foododo_landing"
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
  }

  artifacts {
    type = "CODEPIPELINE"
  }
}

resource "aws_iam_role" "pipeline" {
  name = "your-pipeline-role-name"

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
  name = "your-pipeline-role-policy-name"
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
      // Add more permissions as per your requirements
    ]
  })
}
resource "aws_iam_role" "codebuild" {
  name = "your-codebuild-role-name"

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

resource "aws_iam_role_policy" "codebuild" {
  name = "your-codebuild-role-policy-name"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "logs:CreateLogGroup",  // Required for creating log groups
          "logs:CreateLogStream", // Required for creating log streams
          "logs:PutLogEvents"     // Required for adding log events
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      // Add more permissions as per your requirements
    ]
  })
}
