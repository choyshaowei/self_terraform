variable "AWS_REGION" {
  description = "AWS region"
  type        = string
}

variable "AWS_ACCOUNT_ID" {
  description = "AWS account ID"
  type        = string
  sensitive   = true
}

variable "AWS_ACCESS_KEY_ID" {
  description = "AWS access key ID"
  type        = string
  sensitive   = true
}

variable "AWS_SECRET_ACCESS_KEY" {
  description = "AWS secret access key"
  type        = string
  sensitive   = true
}

variable "PROJECT" {
  description = "Project name"
  type        = string
  sensitive   = true
}

variable "ENVIRONMENT_TYPE" {
  description = "Environment type"
  type        = string
  sensitive   = true
}

variable "GITHUB_TOKEN" {
  description = "GitHub token"
  type        = string
  sensitive   = true
}

locals {
  description = "Environment variables"
  CODEBUILD_ENV_VARS = {
    AWS_REGION       = var.AWS_REGION
    AWS_ACCOUNT_ID   = var.AWS_ACCOUNT_ID
    ECS_CLUSTER_NAME = var.ECS_CLUSTER_NAME
    EKS_CLUSTER_NAME = var.EKS_CLUSTER_NAME
    ASSUME_ROLE_ARN  = var.ASSUME_ROLE_ARN
    ENVIRONMENT_TYPE = var.ENVIRONMENT_TYPE
    PROJECT          = "${var.PROJECT}"
    IMAGE_NAME       = "${var.PROJECT}"
    OBJECT_TYPE      = "deployment"
    OBJECT_NAME      = var.EKS_CLUSTER_NAME
    NAMESPACE        = "default"
    CONTAINER_NAME   = "foododo-foododo-landing"
  }
}

variable "ECS_CLUSTER_NAME" {
  description = "Specifies the ECS Cluster Name with which the resources would be associated"
  type        = string
}
variable "EKS_CLUSTER_NAME" {
  description = "Specifies the EKS Cluster Name with which the resources would be associated"
  type        = string
}
variable "ASSUME_ROLE_ARN" {
  description = "Specifies ASSUME_ROLE_ARN for EKS"
  type        = string
}
variable "VpcId" {
  description = "Optional - Specifies the ID of an existing VPC in which to launch your container instances"
  type        = string
  default     = ""
  validation {
    condition     = can(regex("^(?:vpc-[0-9a-f]{8,17}|)$", var.VpcId))
    error_message = "VPC ID must begin with 'vpc-' and have a valid UUID."
  }
}

variable "SubnetIds" {
  description = "Optional - Specifies the comma-separated list of existing VPC Subnet IDs where ECS instances will run"
  type        = list(string)
  default     = ["subnet-01af3eb08ae779c8b"]
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

variable "EksInstanceTypes" {
  description = "Specifies the EksInstanceTypes"
  type        = list(string)
  default     = ["t3.small"]
}

variable "EksAmiTypes" {
  description = "Specifies the EksAmiTypes"
  type        = string
  default     = "AL2_x86_64"
}

data "aws_availability_zones" "available" {}
