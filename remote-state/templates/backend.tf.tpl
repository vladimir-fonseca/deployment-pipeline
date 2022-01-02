terraform {
backend "s3" {
    bucket         = "${bucket}"
    acl            = "${acl}"
    region         = "${region}"
    encrypt        = "${encrypt}"
    dynamodb_table = "${dynamodb_table }"
    key            = "${key}"
  }
}