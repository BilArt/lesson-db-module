# lesson-db-module / RDS Module

Модуль піднімає **звичайну RDS** (PostgreSQL/MySQL) або **Aurora** залежно від прапора `use_aurora`.

## Приклад використання

```hcl
module "vpc" {
  source      = "./modules/vpc"
  name        = "lesson-db"
  cidr_block  = "10.0.0.0/16"
  az_count    = 2
  tags = { Project = "goit", Env = "lesson-db-module" }
}

module "rds" {
  source = "./modules/rds"

  name         = "lesson-db"
  use_aurora   = true                # false -> aws_db_instance
  engine       = "aurora-postgresql" # або "postgres", "mysql", "aurora-mysql"
  engine_version = "14.10"
  instance_class  = "db.t3.medium"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids  # прод
  # або public_subnet_ids (для тестів)

  port     = 5432
  username = "dbadmin"
  password = var.db_master_password

  multi_az              = false
  allocated_storage     = 20
  max_allocated_storage = 0
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = null
  iam_auth              = false

  backup_retention_days     = 7
  preferred_backup_window   = "03:00-05:00"
  deletion_protection       = false

  allowed_cidr_blocks = [
    "10.0.0.0/16",
    # додай свій публічний IP /32 для тестів
  ]

  parameters = {
    max_connections = "300"
    log_statement   = "none"
  }

  tags = { Project = "goit", Env = "lesson-db-module" }
}
