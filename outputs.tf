output "db_sg_id"           { value = module.rds.security_group_id }
output "db_subnet_group"    { value = module.rds.subnet_group_name }
output "db_endpoint"        { value = coalesce(module.rds.aurora_endpoint, module.rds.db_endpoint) }
output "db_reader_endpoint" { value = module.rds.aurora_reader_endpoint }
