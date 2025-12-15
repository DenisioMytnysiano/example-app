terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.92"
    }
  }

  backend "s3" {
    bucket = "terraform-state-bucket-6944226566"
    key    = "state.tfstate"
    region = "us-west-1"
    profile = ""
  }

  required_version = ">= 1.2"
}

provider "aws" {
  region = "us-west-1"
}

