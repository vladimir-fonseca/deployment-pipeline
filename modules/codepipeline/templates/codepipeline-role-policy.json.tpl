{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:Get*",
        "s3:Put*",
        "s3:List*"
      ],
      "Resource": [
        "${codepipeline_bucket_arn}",
        "${codepipeline_bucket_arn}/*"
      ]
    },
    {
      "Effect" : "Allow",
      "Action" : "iam:PassRole",
      "Resource" : "${codebuild_iam_role_arn}"
    },
    {
      "Effect" : "Allow",
      "Action" : "cloudwatch:*",
      "Resource" : "*"
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
        "codecommit:GetBranch",
      ],
      "Resource" : "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
        "codebuild:StopBuild",
        "codedeploy:*"
      ],
      "Resource": "${codebuild_projects_arn}"
    }
  ]
}