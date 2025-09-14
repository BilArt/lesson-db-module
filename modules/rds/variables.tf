variable "name"               { type = string }
variable "engine"             { type = string }   # postgres | mysql | aurora-postgresql | aurora-mysql
variable "engine_version"     { type = string }

variable "use_aurora" {
  type    = bool
  default = false
}

variable "instance_class" {
  type    = string
  default = "db.t3.medium"
}

variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }

variable "allowed_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "port" {
  type    = number
  default = 5432
}

variable "username" {
  type    = string
  default = "dbadmin"
}

variable "password" {
  type      = string
  sensitive = true
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "max_allocated_storage" {
  type    = number
  default = 0
}

variable "storage_type" {
  type    = string
  default = "gp3"
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "preferred_backup_window" {
  type    = string
  default = "03:00-05:00"
}

variable "deletion_protection" {
  type    = bool
  default = false
}

variable "kms_key_id" {
  type    = string
  default = null
}

variable "storage_encrypted" {
  type    = bool
  default = true
}

variable "iam_auth" {
  type    = bool
  default = false
}

variable "parameters" {
  type = map(string)
  default = {
    max_connections = "200"
    log_statement   = "none"
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}
