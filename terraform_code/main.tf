### SPA Bucket

resource "aws_s3_bucket" "aws_spa_website_bucket" {
  bucket = local.spa_bucket_name
}

locals {
  spa_bucket_name = var.aws_spa_website_bucket_name != "" ? var.aws_spa_website_bucket_name : "${var.aws_resource_identifier}-sp"
}

resource "aws_s3_bucket_public_access_block" "aws_spa_website_bucket" {
  bucket                  = aws_s3_bucket.aws_spa_website_bucket.id
  block_public_acls       = var.aws_spa_cdn_enabled ? true : false
  block_public_policy     = var.aws_spa_cdn_enabled ? true : false
  ignore_public_acls      = var.aws_spa_cdn_enabled ? true : false
  restrict_public_buckets = var.aws_spa_cdn_enabled ? true : false
}

resource "aws_s3_object" "aws_spa_website_bucket" {  
  for_each = {
    for file in fileset(var.aws_spa_source_folder, "**") :
    file => file
    if !startswith(file, ".")  # Ignore files starting with a dot
  }
  
  bucket         = aws_s3_bucket.aws_spa_website_bucket.id
  key            = each.key
  source         = "${var.aws_spa_source_folder}/${each.key}"
  source_hash    = filemd5("${var.aws_spa_source_folder}/${each.key}")
  ##content_type = "text/html"####
  content_type   = filebase64("${var.aws_spa_source_folder}/${each.key}")
  #content_type   = each.key == "index.html" ? "text/html" : filebase64("${var.aws_spa_source_folder}/${each.key}")
}

output "bucket_url" {
  value = aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name
}

#locals {
#  aws_spa_file_sources = var.aws_spa_file_sources != "" ? [for n in split(",", var.aws_spa_file_sources) : n] : []
#  aws_spa_file_keys    = var.aws_spa_file_keys == "" ? ["${var.aws_spa_file_sources}"] : [for n in split(",", var.aws_spa_file_sources) : n]
#  aws_spa_files_length = length(local.aws_spa_file_sources) < length(local.aws_spa_file_keys) ? length(local.aws_spa_file_sources) : length(local.aws_spa_file_keys)
#}

## SPA Bucket Policies


resource "aws_s3_bucket_policy" "aws_spa_bucket_public_access" {
  count  = var.aws_spa_cdn_enabled ? 0 : 1
  bucket = aws_s3_bucket.aws_spa_website_bucket.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": ["${aws_s3_bucket.aws_spa_website_bucket.arn}/*"]
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "aws_spa_website_bucket" {
  count  = var.aws_spa_cdn_enabled ? 1 : 0
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
      values   = length(aws_cloudfront_distribution.cdn_static_site) > 0 ? [aws_cloudfront_distribution.cdn_static_site[0].arn] : [aws_cloudfront_distribution.cdn_static_site_default_cert[0].arn]
    }
  }
}

resource "aws_s3_bucket_policy" "aws_spa_website_bucket_policy" {
  count  = var.aws_spa_cdn_enabled ? 1 : 0
  bucket = aws_s3_bucket.aws_spa_website_bucket.id
  policy = data.aws_iam_policy_document.aws_spa_website_bucket[0].json
}

### CDN 

resource "aws_cloudfront_distribution" "cdn_static_site_default_cert" {
  count               = var.aws_spa_cdn_enabled ? ( local.selected_arn == "" ? 1 : 0 ) : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.aws_spa_cdn_root_object 
  comment             = "CDN for ${var.aws_spa_website_bucket_name}"

  origin {
    domain_name              = aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name
    origin_id                = "aws_spa_bucket_origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default[0].id
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

  viewer_certificate {
    cloudfront_default_certificate = true 

    acm_certificate_arn      = local.selected_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_cloudfront_distribution" "cdn_static_site" {
  count               = var.aws_spa_cdn_enabled ? ( local.selected_arn != "" ? 1 : 0 ) : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.aws_spa_cdn_root_object 
  comment             = "CDN for ${var.aws_spa_website_bucket_name}"

  origin {
    domain_name              = aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name
    origin_id                = "aws_spa_bucket_origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default[0].id
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

  viewer_certificate {
    acm_certificate_arn      = local.selected_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}


locals {
  cdn_aliases = var.aws_r53_domain_name != "" ? ["var.aws_r53_domain_name"] : []
  cdn_site_url = var.aws_spa_cdn_enabled ? ( local.selected_arn != "" ? aws_cloudfront_distribution.cdn_static_site[0].domain_name : aws_cloudfront_distribution.cdn_static_site_default_cert[0].domain_name ) : ""
} 

output "cloudfront_url" {
  value = local.cdn_site_url
}

resource "aws_cloudfront_origin_access_control" "default" {
  count                             = var.aws_spa_cdn_enabled ? 1 : 0
  name                              = "${var.aws_resource_identifier_supershort} - Cloudfront OAC"
  description                       = "Cloudfront OAC for ${var.aws_resource_identifier}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

## ALL DNS

data "aws_route53_zone" "selected" {
  count        = var.aws_r53_domain_name != "" ? 1 : 0
  name         = "${var.aws_r53_domain_name}."
  private_zone = false
}

## RECORDS

resource "aws_route53_record" "dev" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 0 : 1) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site[0].domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "root-a" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 1 : 0) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.aws_r53_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site[0].domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www-a" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 1 : 0) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = "www.{var.aws_r53_domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn_static_site[0].domain_name
    zone_id                = aws_cloudfront_distribution.cdn_static_site[0].hosted_zone_id
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
    (var.aws_spa_cdn_enabled ? "${local.protocol}${local.cdn_site_url}" :
     aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name
    )
  )


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