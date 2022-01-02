terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = local.aws_region
}

locals {
  aws_region = var.region
  prefix     = "web-server"
  ssm_prefix = "/org/web-server/terraform"

  tags = {
    Project   = local.prefix
    ManagedBy = "Terraform"
  }
}

data "aws_ssm_parameter" "kms_key_arn" {
  name = "${local.ssm_prefix}/terraform-remote-state-kms_key_arn"
}

data "aws_ssm_parameter" "locks_table_arn" {
  name = "${local.ssm_prefix}/terraform-locks-table-arn"
}

module "codepipeline" {
  source = "../modules/codepipeline"

  prefix                  = local.prefix
  github_token           = var.github_config.github_token
  repository_name        = var.github_config.repository_name
  repository_owner       = var.github_config.repository_owner
  repository_branch_name = var.github_config.repository_branch_name
  kms_key_arn            = data.aws_ssm_parameter.kms_key_arn.value
  locks_table_arn        = data.aws_ssm_parameter.locks_table_arn.value
  build_backend          = {
    bucket          = var.backend_bucket
    acl             = var.backend_acl
    encrypt         = var.backend_encrypt
    dynamodb_table  = var.backend_dynamodb_table
    key             = format("build-%s", local.prefix)
  }
  tags                   = local.tags
}


