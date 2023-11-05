output "table" {
  value = {
    "name"       = aws_dynamodb_table.main.name
    "stream_arn" = aws_dynamodb_table.main.stream_arn

  }
}
