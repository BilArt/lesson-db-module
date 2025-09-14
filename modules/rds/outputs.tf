output "security_group_id" {
  value = aws_security_group.this.id
}
output "subnet_group_name" {
  value = aws_db_subnet_group.this.name
}

output "db_instance_id" {
  value = try(aws_db_instance.this[0].id, null)
}
output "db_endpoint" {
  value = try(aws_db_instance.this[0].address, null)
}

output "aurora_cluster_id" {
  value = try(aws_rds_cluster.this[0].id, null)
}
output "aurora_endpoint" {
  value = try(aws_rds_cluster.this[0].endpoint, null)
}
output "aurora_reader_endpoint" {
  value = try(aws_rds_cluster.this[0].reader_endpoint, null)
}
