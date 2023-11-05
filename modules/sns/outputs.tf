output "topic" {
  value = {
    arn = aws_sns_topic.main.arn
  }
}
