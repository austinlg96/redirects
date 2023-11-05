output "certificate" {
  value = {
    arn = aws_acm_certificate.cert.arn
  }
}
