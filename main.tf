provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}


resource "aws_instance" "terraform" {
  ami           = "ami-052f483c20fa1351a"
  instance_type = "t2.micro"
}
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


# # Define provider and AWS region
# provider "aws" {
#   region = "us-west-2" # Update with your desired region
# }

# # Create VPC
# resource "aws_vpc" "example_vpc" {
#   cidr_block = "10.0.0.0/16"
# }

# # Create subnets
# resource "aws_subnet" "example_subnet_dev" {
#   vpc_id            = aws_vpc.example_vpc.id
#   cidr_block        = "10.0.1.0/24"
#   availability_zone = "us-west-2a" # Update with your desired availability zone
# }

# resource "aws_subnet" "example_subnet_prod" {
#   vpc_id            = aws_vpc.example_vpc.id
#   cidr_block        = "10.0.2.0/24"
#   availability_zone = "us-west-2b" # Update with your desired availability zone
# }

# # Create security group
# resource "aws_security_group" "example_security_group" {
#   vpc_id = aws_vpc.example_vpc.id

#   # Define your desired security group rules
#   # ...

#   # Example rule to allow HTTP traffic
#   ingress {
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }
# }

# # Create frontend and backend instances (EC2 instances, ECS, or any other service you prefer)
# resource "aws_instance" "example_frontend_dev" {
#   # Configure the instance details for the frontend in the dev environment
#   # ...

#   # Use the dev subnet and security group
#   subnet_id              = aws_subnet.example_subnet_dev.id
#   vpc_security_group_ids = [aws_security_group.example_security_group.id]

#   # ...
# }

# resource "aws_instance" "example_backend_dev" {
#   # Configure the instance details for the backend in the dev environment
#   # ...

#   # Use the dev subnet and security group
#   subnet_id              = aws_subnet.example_subnet_dev.id
#   vpc_security_group_ids = [aws_security_group.example_security_group.id]

#   # ...
# }

# resource "aws_instance" "example_frontend_prod" {
#   # Configure the instance details for the frontend in the production environment
#   # ...

#   # Use the prod subnet and security group
#   subnet_id              = aws_subnet.example_subnet_prod.id
#   vpc_security_group_ids = [aws_security_group.example_security_group.id]

#   # ...
# }

# resource "aws_instance" "example_backend_prod" {
#   # Configure the instance details for the backend in the production environment
#   # ...

#   # Use the prod subnet and security group
#   subnet_id              = aws_subnet.example_subnet_prod.id
#   vpc_security_group_ids = [aws_security_group.example_security_group.id]

#   # ...
# }

# # Create CodePipeline
# resource "aws_codepipeline" "example_codepipeline" {
#   name     = "example-codepipeline"
#   role_arn = aws_iam_role.example_codepipeline_role.arn

#   artifact_store {
#     location = "example-codepipeline-bucket"
#     type     = "S3"
#   }

#   stage {
#     name = "Source"

#     action {
#       name             = "SourceAction"
#       category         = "Source"
#       owner            = "ThirdParty"
#       provider         = "GitHub"
#       version          = "1"
#       output_artifacts = ["source_output"]

#       configuration = {
#         OAuthToken = var.github_oauth_token
#         Owner      = var.github_repo_owner
#         Repo       = var.github_repo_name
#         Branch     = "master"
#       }
#     }
#   }

#   # Add more stages and actions for build, test, and deployment as needed
#   # ...
# }

# # Create IAM role for CodePipeline
# resource "aws_iam_role" "example_codepipeline_role" {
#   name = "example-codepipeline-role"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "codepipeline.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

# # Attach IAM policy to the CodePipeline role
# resource "aws_iam_policy_attachment" "example_codepipeline_policy_attachment" {
#   name       = "example-codepipeline-policy-attachment"
#   roles      = [aws_iam_role.example_codepipeline_role.name]
#   policy_arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess" # Update with desired CodePipeline policy ARN
# }

# # Create S3 bucket for CodePipeline artifact storage
# resource "aws_s3_bucket" "example_codepipeline_bucket" {
#   bucket = "example-codepipeline-bucket"
#   acl    = "private"
#   # ...
# }
