variable "function_name" {
  default = "ask"
}

variable "project_name" {
  default = "findly"
}

variable "lambda_bucket" {
  default = "findly-lambdas"
}

variable "handler" {
  default = "main.lambda_handler"
}

variable "runtime" {
  default = "python3.12"
}

variable "timeout" {
  default = 180
}

variable "memory_size" {
  default = 1024
}

variable "aws_region" {
  default = "us-east-1"
}

variable "dynamodb_table_name" {
  default = "findly-content-hashes"
}

variable "dynamodb_table_index" {
  default = "datetime_index"
}

variable "aws_account" { 
}

variable "FINDLY_SECRET_NAME" {
}
