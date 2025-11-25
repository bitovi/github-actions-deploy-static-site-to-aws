### CDN

locals {
  aws_site_cdn_response_headers_policy_id = var.aws_site_cdn_response_headers_policy_id != "" ? [
    for n in split(",", var.aws_site_cdn_response_headers_policy_id) : (n)
  ] : []
  parsed_aliases = [for n in split(",", var.aws_site_cdn_aliases) : (n)]
}

### CDN Without DNS
resource "aws_cloudfront_distribution" "cdn_static_site_default_cert" {
  count               = var.aws_site_cdn_enabled ? (local.cert_available ? 0 : 1) : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.aws_site_root_object
  comment             = "CDN for ${local.s3_bucket_name} static"

  origin {
    domain_name              = aws_s3_bucket.aws_site_website_bucket.bucket_regional_domain_name
    origin_id                = "aws_site_bucket_origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default[0].id
  }

  default_cache_behavior {
    min_ttl                = var.aws_site_cdn_min_ttl
    default_ttl            = var.aws_site_cdn_default_ttl
    max_ttl                = var.aws_site_cdn_max_ttl
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "aws_site_bucket_origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    response_headers_policy_id = length(local.aws_site_cdn_response_headers_policy_id) > 0 ? local.aws_site_cdn_response_headers_policy_id[0] : null
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  dynamic "custom_error_response" {
    for_each = { for idx, val in local.aws_site_cdn_custom_error_codes : idx => val }

    content {
      error_caching_min_ttl = try(custom_error_response.value.error_caching_min_ttl, null)
      error_code            = custom_error_response.value.error_code
      response_code         = try(custom_error_response.value.response_code, null)
      response_page_path    = try(custom_error_response.value.response_page_path, null)
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

### CDN with custom DNS
resource "aws_cloudfront_distribution" "cdn_static_site" {
  count               = var.aws_site_cdn_enabled ? (local.cert_available ? 1 : 0) : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.aws_site_root_object
  comment             = "CDN for ${local.s3_bucket_name}"

  origin {
    domain_name              = aws_s3_bucket.aws_site_website_bucket.bucket_regional_domain_name
    origin_id                = "aws_site_bucket_origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.default[0].id
  }

  default_cache_behavior {
    min_ttl                = var.aws_site_cdn_min_ttl
    default_ttl            = var.aws_site_cdn_default_ttl
    max_ttl                = var.aws_site_cdn_max_ttl
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "aws_site_bucket_origin"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    response_headers_policy_id = length(local.aws_site_cdn_response_headers_policy_id) > 0 ? local.aws_site_cdn_response_headers_policy_id[0] : null
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  dynamic "custom_error_response" {
    for_each = { for idx, val in local.aws_site_cdn_custom_error_codes : idx => val }

    content {
      error_caching_min_ttl = try(custom_error_response.value.error_caching_min_ttl, null)
      error_code            = custom_error_response.value.error_code
      response_code         = try(custom_error_response.value.response_code, null)
      response_page_path    = try(custom_error_response.value.response_page_path, null)
    }
  }

  aliases = var.aws_site_cdn_aliases != "" ? local.parsed_aliases : [var.aws_r53_root_domain_deploy ? "${var.aws_r53_domain_name}" : "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"]

  viewer_certificate {
    acm_certificate_arn      = local.selected_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
    aws_acm_certificate.sub_domain,
    aws_acm_certificate.root_domain,
    data.aws_acm_certificate.issued
  ]
}

### CDN Access control
resource "aws_cloudfront_origin_access_control" "default" {
  count                             = var.aws_site_cdn_enabled ? 1 : 0
  name                              = "${local.s3_bucket_name}"
  description                       = "Cloudfront OAC for ${local.s3_bucket_name} - ${var.aws_resource_identifier}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
