
#---------------------------------------------------------------------------------------------------
# KMS Key to Encrypt S3 Bucket
#---------------------------------------------------------------------------------------------------
resource "aws_kms_key" "remote" {
  description             = var.kms_key_description
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = var.kms_key_enable_key_rotation

  tags = var.tags
}

resource "aws_kms_key" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  description             = var.kms_key_description
  deletion_window_in_days = var.kms_key_deletion_window_in_days
  enable_key_rotation     = var.kms_key_enable_key_rotation

  tags = var.tags
}

#---------------------------------------------------------------------------------------------------
# Buckets
#---------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "state" {
  bucket_prefix  = var.override_s3_bucket_name ? null : var.state_bucket_prefix
  bucket        = var.override_s3_bucket_name ? var.s3_bucket_name : null
  acl           = "private"
  force_destroy = var.s3_bucket_force_destroy

  versioning {
    enabled = true
  }

  object_lock_configuration {
    object_lock_enabled = "Enabled"
  }

  dynamic "logging" {
    for_each = var.s3_logging_target_bucket != null ? [true] : []
    content {
      target_bucket = var.s3_logging_target_bucket
      target_prefix = var.s3_logging_target_prefix
    }
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.remote.arn
      }
      bucket_key_enabled  = true
    }
  }

  dynamic "replication_configuration" {
    for_each = var.enable_replication == true ? [1] : []
    content {
      role = var.iam_role_arn != null ? var.iam_role_arn : aws_iam_role.replication[0].arn
      rules {
        id     = "replica_configuration"
        prefix = ""
        status = "Enabled"

        source_selection_criteria {
          sse_kms_encrypted_objects {
            enabled = true
          }
        }

        destination {
          bucket             = aws_s3_bucket.replica[0].arn
          storage_class      = "STANDARD"
          replica_kms_key_id = aws_kms_key.replica[0].arn
        }
      }
    }
  }

  dynamic "lifecycle_rule" {
    for_each = local.define_lifecycle_rule ? [true] : []

    content {
      enabled = true
      dynamic "noncurrent_version_transition" {
        for_each = var.noncurrent_version_transitions

        content {
          days          = noncurrent_version_transition.value.days
          storage_class = noncurrent_version_transition.value.storage_class
        }
      }
      dynamic "noncurrent_version_expiration" {
        for_each = var.noncurrent_version_expiration != null ? [var.noncurrent_version_expiration] : []

        content {
          days = noncurrent_version_expiration.value.days
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica

  bucket_prefix  = var.override_s3_bucket_name ? null : var.replica_bucket_prefix
  bucket        = var.override_s3_bucket_name ? var.s3_bucket_name_replica : null

  force_destroy = var.s3_bucket_force_destroy

  versioning {
    enabled = true
  }

  object_lock_configuration {
    object_lock_enabled = "Enabled"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = join("", aws_kms_key.replica.*.arn)
      }
      bucket_key_enabled = true
    }
  }
  dynamic "lifecycle_rule" {
    for_each = local.define_lifecycle_rule ? [true] : []

    content {
      enabled = true
      dynamic "noncurrent_version_transition" {
        for_each = var.noncurrent_version_transitions

        content {
          days          = noncurrent_version_transition.value.days
          storage_class = noncurrent_version_transition.value.storage_class
        }
      }
      dynamic "noncurrent_version_expiration" {
        for_each = var.noncurrent_version_expiration != null ? [var.noncurrent_version_expiration] : []

        content {
          days = noncurrent_version_expiration.value.days
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "replica" {
  count    = var.enable_replication ? 1 : 0
  provider = aws.replica
  bucket   = join("", aws_s3_bucket.replica.*.id)

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


#---------------------------------------------------------------------------------------------------
# IAM Role for Replication
# https://docs.aws.amazon.com/AmazonS3/latest/dev/crr-replication-config-for-kms-objects.html
#---------------------------------------------------------------------------------------------------
resource "aws_iam_role" "replication" {
  count = local.replication_role_count

  name_prefix = var.iam_role_name_prefix

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
POLICY

  tags = var.tags
}

resource "aws_iam_policy" "replication" {
  count = local.replication_role_count

  name_prefix = var.iam_policy_name_prefix
  policy     = templatefile("${path.module}/templates/s3-bucket-iam-role-replication-policy.json.tpl", {
    aws_region_origin     = data.aws_region.state.name
    aws_region_replica    = join("", data.aws_region.replica.*.name)
    s3_bucket_origin_arn  = aws_s3_bucket.state.arn
    s3_bucket_replica_arn = join("", aws_s3_bucket.replica.*.arn)
    kms_key_origin_arn    = aws_kms_key.remote.arn
    kms_key_replica_arn   = join("", aws_kms_key.replica.*.arn)

  })
}

resource "aws_iam_policy_attachment" "replication" {
  count = local.replication_role_count

  name       = var.iam_policy_attachment_name
  roles      = [aws_iam_role.replication[0].name]
  policy_arn = aws_iam_policy.replication[0].arn
}

#---------------------------------------------------------------------------------------------------
# Bucket Policies
#---------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "state_force_ssl" {
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      aws_s3_bucket.state.arn,
      "${aws_s3_bucket.state.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "replica_force_ssl" {
  count = var.enable_replication ? 1 : 0
  statement {
    sid     = "AllowSSLRequestsOnly"
    actions = ["s3:*"]
    effect  = "Deny"
    resources = [
      join("", aws_s3_bucket.replica.*.arn),
      "${join("", aws_s3_bucket.replica.*.arn)}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_s3_bucket_policy" "state_force_ssl" {
  depends_on = [aws_s3_bucket_public_access_block.state]
  bucket     = aws_s3_bucket.state.id
  policy     = data.aws_iam_policy_document.state_force_ssl.json
}

resource "aws_s3_bucket_policy" "replica_force_ssl" {
  count      = var.enable_replication ? 1 : 0
  depends_on = [aws_s3_bucket_public_access_block.replica]
  provider   = aws.replica
  bucket     = join("", aws_s3_bucket.replica.*.id)
  policy     = join("", data.aws_iam_policy_document.replica_force_ssl.*.json)
}

#---------------------------------------------------------------------------------------------------
# DynamoDB Table for State Locking
#---------------------------------------------------------------------------------------------------

resource "aws_dynamodb_table" "lock" {
  name         = "${var.dynamodb_table_name}-${aws_s3_bucket.state.bucket}"
  billing_mode = var.dynamodb_table_billing_mode
  hash_key     = local.lock_key_id

  attribute {
    name = local.lock_key_id
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = var.tags
}


#---------------------------------------------------------------------------------------------------
# IAM Policy
# See below for permissions necessary to run Terraform.
# https://www.terraform.io/docs/backends/types/s3.html#example-configuration
#---------------------------------------------------------------------------------------------------
resource "aws_iam_policy" "terraform" {
  count = var.terraform_iam_policy_create ? 1 : 0

  name_prefix = var.terraform_iam_policy_name_prefix
  policy     = templatefile("${path.module}/templates/s3-bucket-iam-role-policy.json.tpl", {
    bucket_arn         = aws_s3_bucket.state.arn
    dynamodb_table_arn = aws_dynamodb_table.lock.arn
    kms_key_arn        = aws_kms_key.remote.arn
  })
}
