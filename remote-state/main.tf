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

module "remote_state" {
  source = "../modules/remote-state"
  providers = {
    aws         = aws
    aws.replica = aws
  }

  state_bucket_prefix = format("%s-remote-state-", local.prefix)
  enable_replication  = false
  tags                = local.tags
}

resource "aws_ssm_parameter" "remote_state_bucket" {
  name   = "${local.ssm_prefix}/terraform-remote-state-bucket"
  type   = "SecureString"
  key_id = module.remote_state.kms_key.arn
  value  = module.remote_state.bucket.id
  tags   = local.tags
}

resource "aws_ssm_parameter" "locks_table_arn" {
  name   = "${local.ssm_prefix}/terraform-locks-table-arn"
  type   = "String"
  // key_id = module.remote_state.kms_key.arn
  value  = module.remote_state.dynamodb_table.arn
}

resource "aws_ssm_parameter" "remote_state_key" {
  name   = "${local.ssm_prefix}/terraform-remote-state-key"
  type   = "SecureString"
  key_id = module.remote_state.kms_key.arn
  value  = format("%s-pipeline.tfstate", local.prefix)
  tags   = local.tags
}

resource "aws_ssm_parameter" "remote_state_dynamodb_table" {
  name   = "${local.ssm_prefix}/terraform-remote-state-dynamodb_table"
  type   = "SecureString"
  key_id = module.remote_state.kms_key.arn
  value  = module.remote_state.dynamodb_table.name
  tags   = local.tags
}

resource "aws_ssm_parameter" "remote_state_kms_key_arn" {
  name   = "${local.ssm_prefix}/terraform-remote-state-kms_key_arn"
  type   = "String"
  // key_id = module.remote_state.kms_key.arn
  value  = module.remote_state.kms_key.arn
  tags   = local.tags
}

resource "local_file" "env_remote_state" {
  content = templatefile("./templates/backend.tpl",
      {
        config = {
          TF_VAR_backend_bucket          = module.remote_state.bucket.id
          TF_VAR_backend_key             = format("%s-pipeline.tfstate", local.prefix)
          TF_VAR_backend_region          = local.aws_region
          TF_VAR_backend_acl             = "private"
          TF_VAR_backend_encrypt         = true
          TF_VAR_backend_dynamodb_table  = module.remote_state.dynamodb_table.name
        }
      })
  filename = "env_backend.sh"
}