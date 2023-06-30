# # ECS
# data "aws_ssm_parameter" "LatestECSOptimizedAMI" {
#   name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
# }

# resource "aws_ecs_cluster" "ecs_cluster" {
#   name = var.ECS_CLUSTER_NAME

#   setting {
#     name  = "containerInsights"
#     value = "enabled"
#   }

#   configuration {
#     execute_command_configuration {
#       logging = "DEFAULT"
#     }
#   }

#   tags = {
#     name       = "aws_ecs_cluster ecs_cluster"
#     managed_by = "terraform"
#   }
# }

# resource "aws_ecs_cluster_capacity_providers" "example" {
#   cluster_name = var.ECS_CLUSTER_NAME

#   capacity_providers = ["FARGATE"]

#   default_capacity_provider_strategy {
#     base              = 1
#     weight            = 100
#     capacity_provider = "FARGATE"
#   }
# }

# resource "aws_launch_template" "ecs_launch_template" {
#   image_id      = data.aws_ssm_parameter.LatestECSOptimizedAMI.value
#   instance_type = "t4g.small"

#   iam_instance_profile {
#     arn = var.IamRoleInstanceProfile
#   }

#   user_data = base64encode(var.UserData)
# }

# resource "aws_autoscaling_group" "ecs_auto_scaling_group" {
#   launch_template {
#     id      = aws_launch_template.ecs_launch_template.id
#     version = "$Latest"
#   }
#   desired_capacity    = 1
#   min_size            = 1
#   max_size            = 1
#   vpc_zone_identifier = var.SubnetIds
#   tag {
#     key                 = "Name"
#     value               = "ECS Instance - ${var.ECS_CLUSTER_NAME}"
#     propagate_at_launch = true
#   }
# }

# resource "aws_ecs_capacity_provider" "ec2_capacity_provider" {
#   name = "${var.ECS_CLUSTER_NAME}CapacityProvider"

#   auto_scaling_group_provider {
#     auto_scaling_group_arn = aws_autoscaling_group.ecs_auto_scaling_group.arn

#     managed_scaling {
#       status                    = "ENABLED"
#       target_capacity           = 100
#       minimum_scaling_step_size = 1
#       maximum_scaling_step_size = 100
#     }

#     managed_termination_protection = "DISABLED"
#   }
# }

# # Security Group
# resource "aws_security_group" "ecs_security_group" {
#   name        = "ecs_security_group"
#   description = "Allow TLS inbound traffic"
#   vpc_id      = aws_vpc.foododo.id

#   depends_on = [aws_vpc.foododo]

#   ingress {
#     description = "TLS from VPC"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# resource "aws_iam_role" "ecs_task_execution_role" {
#   name = "ecs_task_execution_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Principal = {
#           Service = "ecs-tasks.amazonaws.com"
#         },
#         Effect = "Allow",
#       },
#     ]
#   })
# }

# # IAM Policy
# data "aws_iam_policy_document" "ecs_task_execution_policy" {
#   statement {
#     actions = [
#       "ecr:GetAuthorizationToken",
#       "ecr:BatchCheckLayerAvailability",
#       "ecr:GetDownloadUrlForLayer",
#       "ecr:BatchGetImage",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#     ]

#     resources = ["*"]
#   }
# }

# # IAM Role Policy Attachment
# resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
#   role       = aws_iam_role.ecs_task_execution_role.name
#   policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
# }

# # IAM Policy
# resource "aws_iam_policy" "ecs_task_execution_policy" {
#   name        = "ecs_task_execution_policy"
#   description = "Policy that allows ECS to pull images and send logs to CloudWatch"
#   policy      = data.aws_iam_policy_document.ecs_task_execution_policy.json
# }


# # Task Definition
# resource "aws_ecs_task_definition" "foododo_terraform_landing_fargate" {
#   family                   = "${var.PROJECT}-landing-fargate"
#   network_mode             = "awsvpc"
#   requires_compatibilities = ["FARGATE"]
#   cpu                      = "256"
#   memory                   = "512"
#   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

#   container_definitions = jsonencode([
#     {
#       name      = "${var.PROJECT}-landing-ecr"
#       image     = "${var.AWS_ACCOUNT_ID}.dkr.ecr.${var.AWS_REGION}.amazonaws.com/${var.PROJECT}:latest"
#       essential = true
#       portMappings = [
#         {
#           containerPort = 80
#           hostPort      = 80
#           protocol      = "tcp"
#         }
#       ]
#     }
#   ])
# }

# # ECS Service
# resource "aws_ecs_service" "foododo_terraform_landing_fargate_service" {
#   name            = "${var.PROJECT}-terraform-landing-fargate"
#   cluster         = aws_ecs_cluster.ecs_cluster.id
#   task_definition = aws_ecs_task_definition.foododo_terraform_landing_fargate.arn
#   desired_count   = 1
#   launch_type     = "FARGATE"

#   network_configuration {
#     subnets          = var.SubnetIds
#     assign_public_ip = true
#     security_groups  = [aws_security_group.ecs_security_group.id]
#   }
# }


# # # Task Definition
# # resource "aws_ecs_task_definition" "foododo_landing_fargate" {
# #   family                   = "${var.PROJECT}-landing-fargate"
# #   network_mode             = "awsvpc"
# #   requires_compatibilities = ["FARGATE"]
# #   cpu                      = "512"
# #   memory                   = "1024"
# #   execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

# #   container_definitions = jsonencode([
# #     {
# #       name      = "${var.PROJECT}-landing-ecr"
# #       image     = "${var.AWS_ACCOUNT_ID}.dkr.ecr.${var.AWS_REGION}.amazonaws.com/foododo:landing"
# #       essential = true
# #       portMappings = [
# #         {
# #           containerPort = 80
# #           hostPort      = 80
# #           protocol      = "tcp"
# #         }
# #       ]
# #     }
# #   ])
# # }

# # # ECS Service
# # resource "aws_ecs_service" "foododo_landing_fargate_service" {
# #   name            = "${var.PROJECT}-landing-fargate"
# #   cluster         = aws_ecs_cluster.ecs_cluster.id
# #   task_definition = aws_ecs_task_definition.foododo_landing_fargate.arn
# #   desired_count   = 1
# #   launch_type     = "FARGATE"

# #   network_configuration {
# #     subnets          = var.SubnetIds
# #     assign_public_ip = true
# #     security_groups  = [aws_security_group.ecs_security_group.id]
# #   }
# # }

# output "ECSCluster" {
#   description = "The created cluster."
#   value       = aws_ecs_cluster.ecs_cluster.arn
# }

# output "debug_SubnetIds" {
#   description = "Debug output for SubnetIds"
#   value       = var.SubnetIds
# }
