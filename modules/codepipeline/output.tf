output "pipeline_url" {
  value = "https://console.aws.amazon.com/codepipeline/home?region=${var.region}#/view/${aws_codepipeline.pipeline.id}"
}