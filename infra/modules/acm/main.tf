variable "domain_name" {
  type = string
}

data "aws_acm_certificate" "s3_cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
  most_recent = true
}

resource "aws_acm_certificate" "s3_new_cert" {
  count             = data.aws_acm_certificate.s3_cert.arn == null ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "s3_zone" {
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "s3_acm_validation" {
  count   = data.aws_acm_certificate.s3_cert.arn == null ? 1 : 0
  zone_id = data.aws_route53_zone.s3_zone.zone_id
  name    = tolist(aws_acm_certificate.s3_new_cert[0].domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.s3_new_cert[0].domain_validation_options)[0].resource_record_type
  records = [tolist(aws_acm_certificate.s3_new_cert[0].domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "s3_cert_validation" {
  count                   = data.aws_acm_certificate.s3_cert.arn == null ? 1 : 0
  certificate_arn         = aws_acm_certificate.s3_new_cert[0].arn
  validation_record_fqdns = [aws_route53_record.s3_acm_validation[0].fqdn]
}

output "certificate_arn" {
  value = data.aws_acm_certificate.s3_cert.arn != null ? data.aws_acm_certificate.s3_cert.arn : aws_acm_certificate.s3_new_cert[0].arn
}
