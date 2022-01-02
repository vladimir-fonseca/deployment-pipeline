variable "region" {
  default = "us-west-2"
}

variable "github_config" {}

variable "backend_bucket" {}
variable "backend_acl" {}
variable "backend_encrypt" {}
variable "backend_dynamodb_table"{}