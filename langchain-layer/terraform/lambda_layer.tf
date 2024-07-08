#define variables
locals {
  layer_zip_name    = "${var.layer_name}.zip"
  layer_name        = "${var.layer_name}"
}

# upload zip file to s3
resource "aws_s3_object" "lambda_layer_zip" {
  bucket     = var.lambda_bucket
  key        = "lambda_layers/${local.layer_name}/${local.layer_zip_name}"
  acl        = "private"
  source     = "./${local.layer_zip_name}"
  source_hash = filemd5("./${local.layer_zip_name}")
}

# create lambda layer from s3 object
resource "aws_lambda_layer_version" "lambda_layer" {
  s3_bucket           = aws_s3_object.lambda_layer_zip.bucket
  s3_key              = aws_s3_object.lambda_layer_zip.key
  source_code_hash    = filebase64sha256(aws_s3_object.lambda_layer_zip.source)
  layer_name          = local.layer_name
  compatible_runtimes = var.compatible_runtimes
  skip_destroy        = true
}
