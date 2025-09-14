output "bucket" { value = aws_s3_bucket.state.id }
output "table"  { value = aws_dynamodb_table.locks.name }
