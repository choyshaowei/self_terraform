terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = var.AWS_REGION
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
}

module "codepipeline" {
  source = "./resources/codepipeline"
}

module "ecr" {
  source = "./resources/ecr"
}

module "ecs" {
  source = "./resources/ecs"
}

module "network_configuration" {
  source = "./resources/network"
}

