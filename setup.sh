set -euo pipefail

# ===== Настройки =====
AWS_PROFILE="goit"
AWS_REGION="eu-north-1"
TFSTATE_BUCKET="arb-tfstate-${USER}-lesson-db-$(date +%s)"
TFSTATE_TABLE="arb-tf-locks"
DB_PASS="$(openssl rand -base64 24 | tr -d '\n')"

export AWS_PROFILE AWS_REGION

# ===== Структура =====
mkdir -p lesson-db-module/modules/{s3-backend,vpc,rds}
cd lesson-db-module

cat > .gitignore <<'EOF'
.terraform/
.terraform.lock.hcl
terraform.tfstate
terraform.tfstate.backup
crash.log
*.tfvars
*.tfvars.json
.DS_Store
EOF

# ===== Модуль s3-backend =====
cat > modules/s3-backend/variables.tf <<'EOF'
variable "bucket_name" { type = string }
variable "dynamodb_table_name" { type = string }
variable "region" { type = string }
variable "tags" { type = map(string), default = {} }
EOF

cat > modules/s3-backend/s3.tf <<'EOF'
resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name
  tags   = var.tags
}
resource "aws_s3_bucket_versioning" "ver" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "enc" {
  bucket = aws_s3_bucket.state.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}
resource "aws_s3_bucket_public_access_block" "pab" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
EOF

cat > modules/s3-backend/dynamodb.tf <<'EOF'
resource "aws_dynamodb_table" "locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute { name = "LockID"; type = "S" }
  tags = var.tags
}
EOF

cat > modules/s3-backend/outputs.tf <<'EOF'
output "bucket" { value = aws_s3_bucket.state.id }
output "table"  { value = aws_dynamodb_table.locks.name }
EOF

# ===== Временный bootstrap.tf =====
cat > bootstrap.tf <<EOF
terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}
provider "aws" {
  region  = "${AWS_REGION}"
  profile = "${AWS_PROFILE}"
}
module "tfstate" {
  source              = "./modules/s3-backend"
  bucket_name         = "${TFSTATE_BUCKET}"
  dynamodb_table_name = "${TFSTATE_TABLE}"
  region              = "${AWS_REGION}"
  tags = { Project = "goit", Env = "lesson-db-module" }
}
EOF

terraform init
terraform apply -auto-approve

# ===== Перенос стейта в S3 backend =====
cat > backend.tf <<EOF
terraform {
  required_version = ">= 1.6.0"
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
  backend "s3" {
    bucket         = "${TFSTATE_BUCKET}"
    key            = "lesson-db-module/terraform.tfstate"
    region         = "${AWS_REGION}"
    dynamodb_table = "${TFSTATE_TABLE}"
    encrypt        = true
  }
}
provider "aws" {
  region  = "${AWS_REGION}"
  profile = "${AWS_PROFILE}"
}
EOF

terraform init -migrate-state
rm -f bootstrap.tf

# ===== Мини-VPC =====
cat > modules/vpc/variables.tf <<'EOF'
variable "name" { type = string }
variable "cidr_block" { type = string }
variable "az_count" { type = number, default = 2 }
variable "tags" { type = map(string), default = {} }
EOF

cat > modules/vpc/vpc.tf <<'EOF'
data "aws_availability_zones" "available" {}
resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}
resource "aws_subnet" "private" {
  count                   = var.az_count
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, 8, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = merge(var.tags, { Name = "${var.name}-priv-${count.index + 1}" })
}
EOF

cat > modules/vpc/outputs.tf <<'EOF'
output "vpc_id" { value = aws_vpc.this.id }
output "private_subnet_ids" { value = [for s in aws_subnet.private : s.id] }
EOF

# ===== Модуль RDS =====
cat > modules/rds/variables.tf <<'EOF'
variable "name" { type = string }
variable "engine" { type = string }
variable "engine_version" { type = string }
variable "use_aurora" { type = bool, default = false }
variable "instance_class" { type = string, default = "db.t3.medium" }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "allowed_cidr_blocks" { type = list(string), default = [] }
variable "port" { type = number, default = 5432 }
variable "username" { type = string, default = "dbadmin" }
variable "password" { type = string, sensitive = true }
variable "multi_az" { type = bool, default = false }
variable "allocated_storage" { type = number, default = 20 }
variable "max_allocated_storage" { type = number, default = 0 }
variable "storage_type" { type = string, default = "gp3" }
variable "backup_retention_days" { type = number, default = 7 }
variable "preferred_backup_window" { type = string, default = "03:00-05:00" }
variable "deletion_protection" { type = bool, default = false }
variable "kms_key_id" { type = string, default = null }
variable "storage_encrypted" { type = bool, default = true }
variable "iam_auth" { type = bool, default = false }
variable "parameters" {
  type = map(string)
  default = { max_connections = "200", log_statement = "none" }
}
variable "tags" { type = map(string), default = {} }
EOF

cat > modules/rds/shared.tf <<'EOF'
locals {
  family_map = {
    postgres           = "postgres16"
    mysql              = "mysql8.0"
    aurora-postgresql  = "aurora-postgresql14"
    aurora-mysql       = "aurora-mysql8.0"
  }
  pg_family = lookup(local.family_map, var.engine, null)
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnet-grp"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-subnet-grp" })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-db-sg"
  description = "DB access"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-db-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "db_ingress" {
  for_each          = toset(var.allowed_cidr_blocks)
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = var.port
  to_port           = var.port
}

resource "aws_vpc_security_group_egress_rule" "db_egress_all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = local.pg_family
  description = "Parameter group for ${var.engine}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-pg" })
}
EOF

cat > modules/rds/rds.tf <<'EOF'
resource "aws_db_instance" "this" {
  count                     = var.use_aurora ? 0 : 1
  identifier                = "${var.name}-db"
  engine                    = var.engine
  engine_version            = var.engine_version
  instance_class            = var.instance_class
  username                  = var.username
  password                  = var.password
  port                      = var.port
  db_subnet_group_name      = aws_db_subnet_group.this.name
  vpc_security_group_ids    = [aws_security_group.this.id]
  parameter_group_name      = aws_db_parameter_group.this.name
  multi_az                  = var.multi_az

  allocated_storage         = var.allocated_storage
  max_allocated_storage     = var.max_allocated_storage
  storage_encrypted         = var.storage_encrypted
  storage_type              = var.storage_type
  kms_key_id                = var.kms_key_id

  backup_retention_period   = var.backup_retention_days
  preferred_backup_window   = var.preferred_backup_window

  deletion_protection       = var.deletion_protection
  apply_immediately         = false
  skip_final_snapshot       = true

  iam_database_authentication_enabled = var.iam_auth

  tags = merge(var.tags, { Name = "${var.name}-db" })
}
EOF

cat > modules/rds/aurora.tf <<'EOF'
resource "aws_rds_cluster_parameter_group" "this" {
  count       = var.use_aurora ? 1 : 0
  name        = "${var.name}-cluster-pg"
  family      = local.pg_family
  description = "Cluster parameter group for ${var.engine}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-cluster-pg" })
}

resource "aws_rds_cluster" "this" {
  count                         = var.use_aurora ? 1 : 0
  cluster_identifier            = "${var.name}-aurora-cluster"
  engine                        = var.engine
  engine_version                = var.engine_version
  master_username               = var.username
  master_password               = var.password
  port                          = var.port
  db_subnet_group_name          = aws_db_subnet_group.this.name
  vpc_security_group_ids        = [aws_security_group.this.id]
  kms_key_id                    = var.kms_key_id
  storage_encrypted             = var.storage_encrypted
  backup_retention_period       = var.backup_retention_days
  preferred_backup_window       = var.preferred_backup_window
  deletion_protection           = var.deletion_protection
  apply_immediately             = false
  iam_database_authentication_enabled = var.iam_auth

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this[0].name

  tags = merge(var.tags, { Name = "${var.name}-aurora-cluster" })
}

resource "aws_rds_cluster_instance" "writer" {
  count                   = var.use_aurora ? 1 : 0
  identifier              = "${var.name}-aurora-writer-1"
  cluster_identifier      = aws_rds_cluster.this[0].id
  instance_class          = var.instance_class
  engine                  = var.engine
  engine_version          = var.engine_version
  db_parameter_group_name = aws_db_parameter_group.this.name

  publicly_accessible     = false
  apply_immediately       = false

  tags = merge(var.tags, { Name = "${var.name}-aurora-writer-1" })
}
EOF

cat > modules/rds/outputs.tf <<'EOF'
output "security_group_id" { value = aws_security_group.this.id }
output "subnet_group_name" { value = aws_db_subnet_group.this.name }
output "db_instance_id" { value = try(aws_db_instance.this[0].id, null) }
output "db_endpoint" { value = try(aws_db_instance.this[0].address, null) }
output "aurora_cluster_id" { value = try(aws_rds_cluster.this[0].id, null) }
output "aurora_endpoint" { value = try(aws_rds_cluster.this[0].endpoint, null) }
output "aurora_reader_endpoint" { value = try(aws_rds_cluster.this[0].reader_endpoint, null) }
EOF

# ===== Корень =====
cat > variables.tf <<'EOF'
variable "db_master_password" { type = string, sensitive = true }
EOF

cat > main.tf <<'EOF'
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

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_cidr_blocks = ["10.0.0.0/16"]

  username = "dbadmin"
  password = var.db_master_password

  backup_retention_days   = 7
  preferred_backup_window = "03:00-05:00"
  deletion_protection     = false
  storage_encrypted       = true
  kms_key_id              = null
  iam_auth                = false

  parameters = { max_connections = "300", log_statement = "none" }
  tags = { Project = "goit", Env = "lesson-db-module" }
}
EOF

cat > outputs.tf <<'EOF'
output "db_sg_id"           { value = module.rds.security_group_id }
output "db_subnet_group"    { value = module.rds.subnet_group_name }
output "db_endpoint"        { value = coalesce(module.rds.aurora_endpoint, module.rds.db_endpoint) }
output "db_reader_endpoint" { value = module.rds.aurora_reader_endpoint }
EOF

cat > terraform.tfvars <<EOF
db_master_password = "${DB_PASS}"
EOF

terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

echo "===================="
terraform output
echo "Пароль БД: ${DB_PASS}"
echo "Bucket backend: ${TFSTATE_BUCKET}"
echo "DynamoDB table: ${TFSTATE_TABLE}"
