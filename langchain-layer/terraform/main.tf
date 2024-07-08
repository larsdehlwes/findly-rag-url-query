terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.9"
    }
  }
  backend "s3" {
    bucket = "findly-terraform-state"
    key    = "langchain-layer/tfstate"
    region = "us-east-1"
    shared_credentials_file = "~/.aws/credentials"
    profile = "default"
  }
}

provider "aws" {
  shared_credentials_files = ["~/.aws/credentials"]
  region  = "us-east-1"
  profile = "default"
}
