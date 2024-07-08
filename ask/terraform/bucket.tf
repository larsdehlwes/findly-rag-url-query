resource "aws_s3_object" "project_zip" {
  bucket = var.lambda_bucket
  key    = "${var.function_name}/project.zip"
  acl    = "private"
  source = "./project.zip"
  source_hash = filemd5("./project.zip")
  tags = {
    Name = var.function_name
    Project = var.project_name
  }
}
