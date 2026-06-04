provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      Project     = "streaming-mvp"
      Environment = "dev"
      ManagedBy   = "Terraform"
    }
  }
}