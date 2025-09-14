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
  name = "${var.name}-subnet-grp-pub"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-subnet-grp" })
}

resource "aws_security_group" "this" {
  name        = "${var.name}-db-sg"
  description = "DB access SG"
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

# Parameter group для instance (обычная RDS и Aurora instances)
resource "aws_db_parameter_group" "this" {
  name        = "${var.name}-pg"
  family      = local.pg_family
  description = "Instance parameter group for ${var.engine}"

  dynamic "parameter" {
    for_each = var.parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = "pending-reboot"
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-pg" })
}
