terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.22.0"
    }
  }

  backend "local" {
        path = "prod.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}