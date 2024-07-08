resource "aws_dynamodb_table" "dynamodb_table" {
  name           = var.dynamodb_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "url"
  range_key      = "content_hash"

  attribute {
    name = "url"
    type = "S"
  }
  
  attribute {
    name = "content_hash"
    type = "S"
  }

  attribute {
    name = "last_retrieved"
    type = "S"
  }

  local_secondary_index {
    name = "datetime_index"
    range_key = "last_retrieved"
    projection_type = "ALL"
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = var.dynamodb_table_name
    Project     = var.project_name
  }
}
