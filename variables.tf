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

variable "GITHUB_TOKEN" {
  description = "github-token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "env_vars" {
  default = {
    AWS_REGION     = "ap-southeast-1"
    AWS_ACCOUNT_ID = "640940679593"
    PROJECT        = "foododo"
  }
}
