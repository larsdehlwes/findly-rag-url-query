resource "aws_lambda_function" "lambda_function" {
  s3_bucket = var.lambda_bucket
  s3_key    = aws_s3_object.project_zip.key
  source_code_hash = filebase64sha256(aws_s3_object.project_zip.source)

  runtime       = var.runtime
  handler       = var.handler
  role          = aws_iam_role.lambda_exec_role.arn

  function_name = var.function_name
  timeout = var.timeout
  publish  = "true"
  description = "Lambda function that answers to a question about the content of a URL that was previously indexed to the vector store."
  reserved_concurrent_executions = -1
  memory_size = var.memory_size
  
  tags = {
    Name = var.function_name,
    Project = var.project_name,
  }
  environment {
    variables = {
      FINDLY_SECRET_NAME = var.FINDLY_SECRET_NAME,
    }
  }

  layers = ["arn:aws:lambda:${var.aws_region}:${var.aws_account}:layer:langchain-layer:1", "arn:aws:lambda:${var.aws_region}:${var.aws_account}:layer:utils-layer:3"]
}
