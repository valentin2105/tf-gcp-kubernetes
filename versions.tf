terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.80.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
  }

  required_version = ">= 0.14"
}

