{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${s3_bucket_origin_arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${s3_bucket_origin_arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": [
        "${s3_bucket_replica_arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": [
        "${kms_key_origin_arn}"
      ],
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${aws_region_origin}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${s3_bucket_origin_arn}/*"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Encrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": [
        "${kms_key_replica_arn}"
      ],
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${aws_region_replica}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "${s3_bucket_replica_arn}/*"
          ]
        }
      }
    }
  ]
}