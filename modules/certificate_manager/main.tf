resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain
  validation_method = "DNS"
}

resource "aws_route53_record" "proofs" {
  for_each = { for index, option in aws_acm_certificate.cert.domain_validation_options : option.resource_record_name => option }
  name     = each.value.resource_record_name
  type     = each.value.resource_record_type
  zone_id  = var.zone_id
  records  = [each.value.resource_record_value]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for p in aws_route53_record.proofs : p.fqdn]
}
