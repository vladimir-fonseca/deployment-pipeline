variable "region" {
  description = "AWS region where the resources will be deployed"
  default = "us-west-2"
}

variable "prefix" {
  description = ""
  default = ""
}

variable "tags" {
  description = "A mapping of tags to assign to all resources"
  type        = map(string)
  default     = {}
}

variable "repository_name" {
  default = "tf-web-server-project"
  description = "CodeCommit repository name for CodePipeline builds"
}

variable "repository_owner" {
  description = "Name of the remote source repository"
  type        = string
}

variable "repository_branch_name" {
  default = "master"
  description = "CodeCommit branch name for CodePipeline builds"
}


variable "kms_key_arn" {
  default = ""
  description = ""
}

variable "github_token" {
  description = "github OATH token"
  default = ""
}

variable "locks_table_arn" {
  default = ""
}

variable "build_backend" {
  type = object({
    bucket          = string
    acl             = string
    encrypt         = string
    dynamodb_table  = string
    key             = string
  })
  default = {
    bucket          = ""
    acl             = ""
    encrypt         = ""
    dynamodb_table  = ""
    key             = ""
  }
}