variable "project_name" {
  default = "findly"
}

variable "compatible_runtimes" {
  default = ["python3.12"]
}

variable "layer_name" {
  default = "langchain-layer"
}

variable "lambda_bucket" {
  default = "findly-lambdas"
}
