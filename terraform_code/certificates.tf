# CERTIFICATE STUFF

data "aws_acm_certificate" "issued" {
  for_each = local.cert_available && local.fqdn_provided ? {
    "domain" : var.aws_r53_domain_name,
    "wildcard" : "*.${var.aws_r53_domain_name}"
    "sub" : "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
  } : {}
  domain = var.aws_r53_domain_name
}

# This block will create and validate the root domain and www cert
resource "aws_acm_certificate" "root_domain" {
  count                     = var.aws_r53_enable_cert ? (var.aws_r53_create_root_cert ? (var.aws_r53_domain_name != "" ? 1 : 0) : 0) : 0
  domain_name               = var.aws_r53_domain_name
  subject_alternative_names = ["*.${var.aws_r53_domain_name}", "${var.aws_r53_domain_name}"]
  validation_method         = "DNS"
}

resource "aws_route53_record" "root_domain" {
  count           = var.aws_r53_enable_cert ? (var.aws_r53_create_root_cert ? (var.aws_r53_domain_name != "" ? 1 : 0) : 0) : 0
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.root_domain[0].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.root_domain[0].domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.root_domain[0].domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.selected[0].zone_id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "root_domain" {
  count                   = var.aws_r53_enable_cert ? (var.aws_r53_create_root_cert ? (var.aws_r53_domain_name != "" ? 1 : 0) : 0) : 0
  certificate_arn         = aws_acm_certificate.root_domain[0].arn
  validation_record_fqdns = [for record in aws_route53_record.root_domain : record.fqdn]
}

# This block will create and validate the sub domain cert ONLY
resource "aws_acm_certificate" "sub_domain" {
  count             = var.aws_r53_enable_cert ? (var.aws_r53_create_sub_cert ? (var.aws_r53_domain_name != "" ? (var.aws_r53_sub_domain_name != "" ? (var.aws_r53_create_root_cert ? 0 : 1) : 0) : 0) : 0) : 0
  domain_name       = "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "sub_domain" {
  count           = var.aws_r53_enable_cert ? (var.aws_r53_create_sub_cert ? (var.aws_r53_domain_name != "" ? (var.aws_r53_sub_domain_name != "" ? (var.aws_r53_create_root_cert ? 0 : 1) : 0) : 0) : 0) : 0
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.sub_domain[0].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.sub_domain[0].domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.sub_domain[0].domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.selected[0].zone_id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "sub_domain" {
  count                   = var.aws_r53_enable_cert ? (var.aws_r53_create_sub_cert ? (var.aws_r53_domain_name != "" ? (var.aws_r53_create_root_cert ? 0 : 1) : 0) : 0) : 0
  certificate_arn         = aws_acm_certificate.sub_domain[0].arn
  validation_record_fqdns = [for record in aws_route53_record.sub_domain : record.fqdn]
}

### Try looking up for the cert with different names
locals {
  acm_arn = try(data.aws_acm_certificate.issued["domain"].arn, try(data.aws_acm_certificate.issued["wildcard"].arn, data.aws_acm_certificate.issued["sub"].arn, ""))
}
