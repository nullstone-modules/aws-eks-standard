terraform {
  required_providers {
    ns = {
      source  = "nullstone-io/ns"
      version = "~> 0.13.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.8"
    }
  }
}
