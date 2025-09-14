resource "aws_db_instance" "this" {
  count                  = var.use_aurora ? 0 : 1
  identifier             = "${var.name}-db"
  engine                 = var.engine                  # postgres | mysql
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  username               = var.username
  password               = var.password
  port                   = var.port

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  parameter_group_name   = aws_db_parameter_group.this.name
  multi_az               = var.multi_az

  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  storage_type           = var.storage_type
  storage_encrypted      = var.storage_encrypted
  kms_key_id             = var.kms_key_id

  backup_retention_period = var.backup_retention_days
  backup_window = var.preferred_backup_window

  deletion_protection    = var.deletion_protection
  apply_immediately      = false
  skip_final_snapshot    = true

  iam_database_authentication_enabled = var.iam_auth

  tags = merge(var.tags, { Name = "${var.name}-db" })
}
