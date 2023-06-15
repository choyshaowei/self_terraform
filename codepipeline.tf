# ECS
resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.ECSClusterName

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }

  capacity_providers = ["FARGATE", "FARGATE_SPOT", aws_ecs_capacity_provider.ec2_capacity_provider.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2_capacity_provider.name
    weight            = 1
    base              = 0
  }
}

resource "aws_launch_template" "ecs_launch_template" {
  image_id      = data.aws_ssm_parameter.LatestECSOptimizedAMI.value
  instance_type = "t4g.small"

  iam_instance_profile {
    arn = var.IamRoleInstanceProfile
  }

  user_data = base64encode(var.UserData)
}

resource "aws_autoscaling_group" "ecs_auto_scaling_group" {
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }
  desired_capacity    = 1
  min_size            = 1
  max_size            = 1
  vpc_zone_identifier = var.SubnetIds
  tag {
    key                 = "Name"
    value               = "ECS Instance - ${var.ECSClusterName}"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ec2_capacity_provider" {
  name = "${var.ECSClusterName}CapacityProvider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs_auto_scaling_group.arn

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = 100
      minimum_scaling_step_size = 1
      maximum_scaling_step_size = 100
    }

    managed_termination_protection = "DISABLED"
  }
}

# Security Group
resource "aws_security_group" "your_security_group" {
  name        = "your_security_group"
  description = "Allow TLS inbound traffic"
  vpc_id      = var.VpcId

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Effect = "Allow",
      },
    ]
  })
}

# Task Definition
resource "aws_ecs_task_definition" "task_def" {
  family                   = "service_family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "your_container_name"
      image     = "${var.AWS_ACCOUNT_ID}.dkr.ecr.${var.AWS_REGION}.amazonaws.com/${var.PROJECT}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "ecs_service" {
  name            = "your_service_name"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.task_def.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.SubnetIds
    assign_public_ip = true
    security_groups  = [aws_security_group.your_security_group.id]
  }
}

output "ECSCluster" {
  description = "The created cluster."
  value       = aws_ecs_cluster.ecs_cluster.arn
}

output "debug_SubnetIds" {
  description = "Debug output for SubnetIds"
  value       = var.SubnetIds
}


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
  # #  Source using codestar connection
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
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["image_definitions"]
      version         = "1"
      configuration = {
        ClusterName = aws_ecs_cluster.ecs_cluster.name
        ServiceName = aws_ecs_service.ecs_service.name
        FileName    = "imagedefinitions.json"
      }
    }
  }

}

# Build and deploy to ECR as a container
resource "aws_codebuild_project" "foododo" {
  name          = "foododo-terraform"
  description   = "foododo-terraform"
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
          "ecr:GetDownloadUrlForLayer"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

module "ecr" {
  source          = "terraform-aws-modules/ecr/aws"
  repository_name = "foododo-terraform"


  repository_read_write_access_arns = [aws_iam_role.ecr_role.arn]
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

