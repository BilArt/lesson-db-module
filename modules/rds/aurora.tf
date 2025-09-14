# Cluster-level parameter group (только для Aurora)
resource "aws_rds_cluster_parameter_group" "this" {
  count       = var.use_aurora ? 1 : 0
  name        = "${var.name}-cluster-pg"
  family      = local.pg_family
  description = "Cluster parameter group for ${var.engine}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-cluster-pg" })
}

resource "aws_rds_cluster" "this" {
  count                         = var.use_aurora ? 1 : 0
  cluster_identifier            = "${var.name}-aurora-cluster"
  engine                        = var.engine                 # aurora-postgresql | aurora-mysql
  engine_version                = var.engine_version
  master_username               = var.username
  master_password               = var.password
  port                          = var.port

  db_subnet_group_name          = aws_db_subnet_group.this.name
  vpc_security_group_ids        = [aws_security_group.this.id]

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this[0].name

  storage_encrypted             = var.storage_encrypted
  kms_key_id                    = var.kms_key_id

  backup_retention_period       = var.backup_retention_days
  preferred_backup_window       = var.preferred_backup_window
  deletion_protection           = var.deletion_protection
  apply_immediately             = false
  skip_final_snapshot = true
  iam_database_authentication_enabled = var.iam_auth

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

  publicly_accessible = true
  apply_immediately       = false

  tags = merge(var.tags, { Name = "${var.name}-aurora-writer-1" })
}
