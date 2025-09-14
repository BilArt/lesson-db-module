module "vpc" {
  source     = "./modules/vpc"
  name       = "lesson-db"
  cidr_block = "10.0.0.0/16"
  tags = { Project = "goit", Env = "lesson-db-module" }
}

module "rds" {
  source = "./modules/rds"

  name           = "lesson-db"
  use_aurora     = true
  engine         = "aurora-postgresql"
  engine_version = "14.10"
  port           = 5432
  instance_class = "db.t3.medium"

  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.public_subnet_ids
  allowed_cidr_blocks = ["10.0.0.0/16", "85.80.32.78/32"]

  username = "dbadmin"
  password = var.db_master_password

  backup_retention_days   = 7
  preferred_backup_window = "03:00-05:00"
  deletion_protection     = false
  storage_encrypted       = true
  kms_key_id              = null
  iam_auth                = false

  parameters = {
    max_connections = "300"
    log_statement   = "none"
  }

  tags = { Project = "goit", Env = "lesson-db-module" }
}
