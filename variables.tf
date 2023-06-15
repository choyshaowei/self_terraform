variable "AWS_REGION" {
  description = "aws-region"
  default     = "ap-southeast-1"
  type        = string
}

variable "AWS_ACCOUNT_ID" {
  description = "aws-account-id"
  type        = string
  sensitive   = true
  default     = ""
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

variable "PROJECT" {
  description = "project"
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

variable "env_vars" {
  type = map(string)
  default = {
    AWS_REGION     = "ap-southeast-1"
    AWS_ACCOUNT_ID = "640940679593"
    PROJECT        = "foododo-terraform"
  }
}

variable "ECSClusterName" {
  description = "Specifies the ECS Cluster Name with which the resources would be associated"
  type        = string
  default     = "arm64ClusterPipeline"
}

variable "VpcId" {
  description = "Optional - Specifies the ID of an existing VPC in which to launch your container instances. If you specify a VPC ID, you must specify a list of existing subnets in that VPC. If you do not specify a VPC ID, a new VPC is created with at least 1 subnet."
  type        = string
  default     = ""
  validation {
    condition     = can(regex("^(?:vpc-[0-9a-f]{8,17}|)$", var.VpcId))
    error_message = "VPC Id must begin with 'vpc-' and have a valid uuid."
  }
}

variable "SubnetIds" {
  description = "Optional - Specifies the Comma separated list of existing VPC Subnet Ids where ECS instances will run"
  type        = list(string)
  default     = ["subnet-0d42c307a30ff2ade", "subnet-0fbc05a19239574dc"]
}
data "aws_ssm_parameter" "LatestECSOptimizedAMI" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/arm64/recommended/image_id"
}
variable "UserData" {
  description = "User data required for Launch Template and Spot Fleet"
  type        = string
  default     = "#!/bin/bash \necho ECS_CLUSTER=arm64Cluster >> /etc/ecs/ecs.config;"
}

variable "IamRoleInstanceProfile" {
  description = "Specifies the Name or the Amazon Resource Name (ARN) of the instance profile associated with the IAM role for the instance"
  type        = string
  default     = "arn:aws:iam::640940679593:instance-profile/ecsInstanceRole"
}

