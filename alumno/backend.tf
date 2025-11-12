terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend S3 compartido - cada alumno tiene su propia key
  # La key se configura dinámicamente durante terraform init
  backend "s3" {
    bucket         = "taller-rag-terraform-state"
    region         = "us-east-1"
    #dynamodb_table = "taller-rag-terraform-locks"
    #encrypt        = true
    # key = configurado dinámicamente con -backend-config
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "TallerRAG"
      Environment = "student"
      AlumnoID   = var.alumno_id
      ManagedBy   = "Terraform"
    }
  }
}
