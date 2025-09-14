terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}
provider "aws" {
  region  = "eu-north-1"
  profile = "goit"
}
module "tfstate" {
  source              = "./modules/s3-backend"
  bucket_name         = "arb-tfstate-artembilousov-lesson-db-1757865590"
  dynamodb_table_name = "arb-tf-locks"
  region              = "eu-north-1"
  tags = { Project = "goit", Env = "lesson-db-module" }
}
