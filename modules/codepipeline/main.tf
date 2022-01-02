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

data "aws_caller_identity" "current" {}

locals {
  aws_region  = var.region
  prefix       = "${var.prefix}-pipeline"
  ssm_prefix   =  "/org/web-server/terraform"
  tags        = var.tags
}