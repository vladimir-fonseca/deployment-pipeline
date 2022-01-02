# CodeBuild IAM
resource "aws_iam_role" "codebuild" {
  name        = "TFCodebuildServiceRole"
  description = "CodeBuild Service Role - Managed by Terraform"
  tags        = local.tags

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild" {
  role   = aws_iam_role.codebuild.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:*"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "iam:*"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "secretsmanage:*"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "codebuild:*"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:*",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem"
          ],
          "Resource" : var.locks_table_arn
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:*"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "ssm:*"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "codebuild_codecommit" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"
}

resource "aws_iam_role_policy_attachment" "codebuild_deploy" {
  role       = aws_iam_role.codebuild.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "codebuild_PowerUserAccess" {
    policy_arn  = "arn:aws:iam::aws:policy/PowerUserAccess"
    role        = aws_iam_role.codebuild.id
}

# Codepipeline IAM
resource "aws_iam_role" "codepipeline" {
  name        = "TFCodepipelineServiceRole"
  description = "CodePipeline Service Role - Managed by Terraform"
  tags        = local.tags

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy" "codepipeline" {
  role = aws_iam_role.codepipeline.id

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect":"Allow",
          "Action": [
            "s3:*"
          ],
          "Resource": "*"
        },
        {
          "Effect" : "Allow",
          "Action" : "iam:PassRole",
          "Resource" : aws_iam_role.codebuild.arn
        },
        {
          "Effect" : "Allow",
          "Action" : "cloudwatch:*",
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "kms:*"
          ],
          "Resource" : "*"
        },
        {
          "Effect": "Allow",
          "Action": [
            "codestar-connections:UseConnection",
            "codestar-connections:GetConnection"
          ],
          "Resource": "arn:aws:codestar-connections:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "codecommit:BatchGet*",
            "codecommit:BatchDescribe*",
            "codecommit:Describe*",
            "codecommit:Get*",
            "codecommit:List*",
            "codecommit:GitPull",
            "codecommit:UploadArchive",
            "codecommit:GetBranch"
          ],
          "Resource" : "*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "codebuild:StartBuild",
            "codebuild:StopBuild",
            "codebuild:BatchGetBuilds"
          ],
          "Resource" : [
            aws_codebuild_project.deploy.arn,
            aws_codebuild_project.destroy.arn
          ]
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "codepipeline_codecommit" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess"
}



#codepipeline
# S3 bucket
resource "aws_s3_bucket" "codepipeline" {
  bucket_prefix  = format("s3-artifacts-%s", local.prefix)
  acl           = "private"
  force_destroy = true

  versioning {
    enabled = false
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = var.kms_key_arn
      }
      bucket_key_enabled  = true
    }
  }

  lifecycle {
    prevent_destroy = false
  }

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "codepipeline" {
  bucket                  = aws_s3_bucket.codepipeline.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  
}

resource "aws_codebuild_project" "deploy" {
  name           = "${local.prefix}-terraform-deploy"
  description    = "Managed using Terraform"
  service_role   = aws_iam_role.codebuild.arn
  tags           = local.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name = "TF_VERSION"
      value = "1.1.2"
    }
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "1"
    }
    environment_variable {
      name  = "TF_LOG"
      value = ""
    }
    environment_variable {
      name  = "TF_VAR_backend_bucket"
      value = var.build_backend.bucket
    }
    environment_variable {
      name  = "TF_VAR_backend_acl"
      value = var.build_backend.acl
    }
    environment_variable {
      name  = "TF_VAR_backend_region"
      value = var.region
    }
    environment_variable {
      name  = "TF_VAR_backend_encrypt"
      value = var.build_backend.encrypt
    }
    environment_variable {
      name  = "TF_VAR_backend_dynamodb_table"
      value = var.build_backend.dynamodb_table
    }
    environment_variable {
      name  = "TF_VAR_backend_key"
      value = var.build_backend.key
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec/terraform-apply.yaml")
  }
}

resource "aws_codebuild_project" "destroy" {
  name           = "${local.prefix}-terraform-destroy"
  description    = "Managed using Terraform"
  service_role   = aws_iam_role.codebuild.arn
  tags           = local.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name = "TF_VERSION"
      value = "1.1.2"
    }
    environment_variable {
      name  = "TF_IN_AUTOMATION"
      value = "1"
    }
    environment_variable {
      name  = "TF_LOG"
      value = ""
    }
    environment_variable {
      name  = "TF_VAR_backend_bucket"
      value = var.build_backend.bucket
    }
    environment_variable {
      name  = "TF_VAR_backend_acl"
      value = var.build_backend.acl
    }
    environment_variable {
      name  = "TF_VAR_backend_region"
      value = var.region
    }
    environment_variable {
      name  = "TF_VAR_backend_encrypt"
      value = var.build_backend.encrypt
    }
    environment_variable {
      name  = "TF_VAR_backend_dynamodb_table"
      value = var.build_backend.dynamodb_table
    }
    environment_variable {
      name  = "TF_VAR_backend_key"
      value = var.build_backend.key
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = file("${path.module}/buildspec/terraform-destroy.yaml")
  }
}


# CodePipeline

resource "aws_codepipeline" "pipeline" {
  name     = local.prefix
  role_arn = aws_iam_role.codepipeline.arn
  tags     = local.tags

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.codepipeline.id

    dynamic "encryption_key" {
      for_each = var.kms_key_arn == null ? [] : tolist([1])
      content {
        id   = var.kms_key_arn
        type = "KMS"
      }
    }
    
  }

  stage {
    name = "Source"
    action {
      run_order        = 1
      version          = "1"
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      configuration     = {
        "OAuthToken"           = var.github_token
        "Repo"                 = var.repository_name
        "Branch"               = var.repository_branch_name
        "Owner"                = var.repository_owner
        "PollForSourceChanges" = "true"
      }
      input_artifacts  = []
      output_artifacts = ["Source"]
    }
  }

  stage {
    name = "Deploy"

    action {
      run_order        = 1
      name             = "terraform-deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["Source"]
      output_artifacts = ["Deploy"]
      version          = "1"

      configuration = {
        ProjectName      = aws_codebuild_project.deploy.name
      }
    }
  }

  stage {
    name = "Destroy-Approval"

    action {
      run_order = 1
      name      = "Approval"
      category  = "Approval"
      owner     = "AWS"
      provider  = "Manual"
      version   = "1"
    }
  }

  stage {
    name = "Destroy"

    action {
      run_order        = 1
      name             = "terraform-deploy"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["Source"]
      output_artifacts = ["Destroy"]
      version          = "1"

      configuration = {
        ProjectName      = aws_codebuild_project.destroy.name
      }
    }
  }
}