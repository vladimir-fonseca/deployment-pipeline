terraform {
  required_version = ">= 0.15"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.39.0"
      configuration_aliases = [aws.replica]
    }
  }
}

data "aws_region" "state" {
}

data "aws_region" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
}

locals {
  # The table must have a primary key named LockID.
  # See below for more detail.
  # https://www.terraform.io/docs/backends/types/s3.html#dynamodb_table
  lock_key_id = "LockID"

  define_lifecycle_rule   = var.noncurrent_version_expiration != null || length(var.noncurrent_version_transitions) > 0
  replication_role_count = var.iam_role_arn == null && var.enable_replication ? 1 : 0

}