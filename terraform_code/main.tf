### SPA Bucket

resource "aws_s3_bucket" "aws_spa_website_bucket" {
  bucket = "var.aws_spa_website_bucket_name" ####
}

resource "aws_s3_account_public_access_block" "aws_spa_website_bucket" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "aws_spa_website_bucket" {.  ### ADD an iteration here
  count          = local.aws_spa_files_length
  bucket         = aws_s3_bucket.aws_spa_website_bucket.id
  key            = local.aws_spa_file_keys[count.index]
  source         = local.aws_spa_file_sources[count.index]
  ##content_type = "text/html"####
}

output "bucket_url" {
  value = aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name
}

locals {
 aws_spa_file_sources = var.aws_spa_file_sources != "" ? [for n in split(",", var.aws_spa_file_sources)  : (n)] : []
 aws_spa_file_keys    = var.aws_spa_file_keys == "" ? var.aws_spa_file_sources : [for n in split(",", var.aws_spa_file_sources)  : (n)] : []
 aws_spa_files_length = length(local.aws_spa_file_sources) < length(local.aws_spa_file_keys) ? length(local.aws_spa_file_sources) : length(local.aws_spa_file_keys)
}

## SPA Bucket Policies

data "aws_iam_policy_document" "aws_spa_website_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.aws_spa_website_bucket.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudfront_distribution.cdn_static_site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "aws_spa_website_bucket_policy" {
  bucket = aws_s3_bucket.aws_spa_website_bucket.id
  policy = data.aws_iam_policy_document.aws_spa_website_bucket.json
}

### CDN 

resource "aws_cloudfront_distribution" "cdn_static_site" {
  count               = var.aws_spa_cdn_enabled ? 1 : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.aws_spa_cdn_root_object 
  comment             = "CDN for ${var.aws_spa_website_bucket_name}"

  origin {
    domain_name              = aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name
    origin_id                = "aws_spa_bucket_origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  default_cache_behavior {
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "aws_spa_bucket_origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  aliases = local.cdn_aliases
  ]

  viewer_certificate {
    acm_certificate_arn      = local.selected_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

locals {
  cdn_aliases = var.aws_r53_domain_name != "" ? ["var.aws_r53_domain_name"] : []
} 

resource "aws_cloudfront_origin_access_control" "default" {
  count                             = var.aws_spa_cdn_enabled ? 1 : 0
  name                              = "${var.aws_resource_identifier} - Cloudfront OAC"
  description                       = "Cloudfront OAC for ${var.aws_resource_identifier}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.cdn_static_site.domain_name
}

## ALL DNS

data "aws_route53_zone" "selected" {
  count        = var.aws_r53_domain_name != "" ? 1 : 0
  name         = "$${var.aws_r53_domain_name}."
  private_zone = false
}

## RECORDS

resource "aws_route53_record" "dev" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 0 : 1) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = "$${var.aws_r53_sub_domain_name}.$${var.aws_r53_domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "root-a" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 1 : 0) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.aws_r53_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www-a" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 1 : 0) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = "www.$${var.aws_r53_domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site.domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site.hosted_zone_id
    evaluate_target_health = false
  }
}

## R53 OUTPUTS

locals {
  url = (local.fqdn_provided ?
    (var.aws_r53_root_domain_deploy ?
      "${local.protocol}${var.aws_r53_domain_name}" :
      "${local.protocol}${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
    ) :
  aws_spa_cdn_enabled ? "${local.protocol}${aws_cloudfront_distribution.cdn_static_site.domain_name}"
  ) : aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name


  fqdn_provided = (
    (var.aws_r53_domain_name != "") ?
    (var.aws_r53_sub_domain_name != "" ?
      true :
      var.aws_r53_root_domain_deploy ? true : false
    ) : 
    false
  )
  protocol = local.cert_available ? "https://" : "http://"
}

output "vm_url" {
  value = local.url
}

# Lookup for main domain.

data "aws_acm_certificate" "issued" {
  count  = var.aws_r53_enable_cert == "true" ? 1 : (var.create_root_cert != "true" ? (var.create_sub_cert != "true" ? (local.fqdn_provided ? 1 : 0) : 0) : 0)
  for_each = var.aws_r53_enable_cert ? {
    "domain" : var.aws_r53_domain_name,
    "wildcard" : "*.${var.aws_r53_domain_name}"
    "sub": "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
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
  count             = var.aws_r53_enable_cert ? (var.aws_r53_create_sub_cert ? (var.aws_r53_domain_name != "" ? (var.aws_r53_sub_domain_name != "" ? (var.aws_r53_create_root_cert ?  0 : 1 ) : 0) : 0) : 0) :0
  domain_name       = "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "sub_domain" {
  count           = var.aws_r53_enable_cert ? (var.aws_r53_create_sub_cert ? (var.aws_r53_domain_name != "" ? (var.aws_r53_sub_domain_name != "" ? (var.aws_r53_create_root_cert ?  0 : 1 ) : 0) : 0) : 0) :0
  allow_overwrite = true
  name            = tolist(aws_acm_certificate.sub_domain[0].domain_validation_options)[0].resource_record_name
  records         = [tolist(aws_acm_certificate.sub_domain[0].domain_validation_options)[0].resource_record_value]
  type            = tolist(aws_acm_certificate.sub_domain[0].domain_validation_options)[0].resource_record_type
  zone_id         = data.aws_route53_zone.selected[0].zone_id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "sub_domain" {
  count                   = var.aws_r53_enable_cert ? (var.aws_r53_create_sub_cert ? (var.aws_r53_domain_name != "" ? (var.aws_r53_create_root_cert ?  0 : 1) : 0) : 0) :0
  certificate_arn         = aws_acm_certificate.sub_domain[0].arn
  validation_record_fqdns = [for record in aws_route53_record.sub_domain : record.fqdn]
}

locals {
  selected_arn = (
    var.aws_r53_enable_cert ? 
    (var.aws_r53_cert_arn != "" ? var.aws_r53_cert_arn :
      (!var.aws_r53_create_root_cert ?
        (!var.aws_r53_create_sub_cert ?
          (local.fqdn_provided ? local.acm_arn : "")
          : aws_acm_certificate.sub_domain[0].arn
        ) : aws_acm_certificate.root_domain[0].arn
      ) 
    ) : ""
  )
  cert_available = (
    var.aws_r53_enable_cert ?
    (var.aws_r53_cert_arn != "" ? true :
      (!var.aws_r53_create_root_cert ?
        (!var.aws_r53_create_sub_cert ?
          (local.fqdn_provided ? true : false)
          : true
        ) : true
      )
    ) : false
  )
  acm_arn = try(data.aws_acm_certificate.issued["domain"].arn, try(data.aws_acm_certificate.issued["wildcard"].arn, data.aws_acm_certificate.issued["sub"].arn, ""))
}

output "selected_arn" {
  value = local.selected_arn
}