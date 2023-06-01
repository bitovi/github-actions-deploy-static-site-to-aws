### SPA Bucket

# Create bucket to store incoming files - If no name is provided, will set a default one
resource "aws_s3_bucket" "aws_spa_website_bucket" {
  bucket = var.aws_spa_website_bucket_name != "" ? var.aws_spa_website_bucket_name : "${var.aws_resource_identifier}-sp"
}

resource "aws_s3_bucket_website_configuration" "aws_spa_website_bucket" {
  bucket = var.aws_spa_website_bucket_name != "" ? var.aws_spa_website_bucket_name : "${var.aws_resource_identifier}-sp"
  index_document {
    suffix = "index.html"
  }
}

# Allow public access to bucket
resource "aws_s3_bucket_public_access_block" "aws_spa_website_bucket" {
  bucket                  = aws_s3_bucket.aws_spa_website_bucket.id
  block_public_policy     = false
  restrict_public_buckets = false
  depends_on = [ aws_s3_bucket.aws_spa_website_bucket ]
}

# Tool to identify file types
module "template_files" {
  source   = "hashicorp/dir/template"
  base_dir = var.aws_spa_source_folder
}

# Will upload each file to the bucket, defining content-type
resource "aws_s3_object" "aws_spa_website_bucket" {
  for_each = module.template_files.files

  bucket       = aws_s3_bucket.aws_spa_website_bucket.id
  key          = each.key
  content_type = contains([".ts", "tsx"], substr(each.key, -3, 3)) ? "text/javascript" : each.value.content_type

  source  = each.value.source_path
  content = each.value.content

  etag = each.value.digests.md5
}

output "bucket_url" {
  value = aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name
}

## SPA Bucket Policies
resource "aws_s3_bucket_policy" "aws_spa_bucket_public_access" {
  count  = var.aws_spa_cdn_enabled ? 0 : 1
  bucket = aws_s3_bucket.aws_spa_website_bucket.id
  depends_on = [ aws_s3_bucket_public_access_block.aws_spa_website_bucket ]
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

data "aws_iam_policy_document" "aws_spa_bucket_public_access_dns" {
  count = local.fqdn_provided ? 1 : 0
  statement {
    actions = [
      "s3:GetObject"
    ]
    principals {
      identifiers = ["*"]
      type = "AWS"
    }
    resources = [ var.aws_r53_root_domain_deploy ? "arn:aws:s3:::${var.aws_r53_domain_name}/*" : "arn:aws:s3:::${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}/*" ]
  }
}

resource "aws_s3_bucket_policy" "aws_spa_website_bucket_policy_dns" {
  count  = local.fqdn_provided ? 1 : 0
  bucket = aws_s3_bucket.aws_spa_website_bucket.id
  policy = data.aws_iam_policy_document.aws_spa_bucket_public_access_dns[0].json
}


data "aws_iam_policy_document" "aws_spa_website_bucket" {
  count = var.aws_spa_cdn_enabled ? 1 : 0
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

### CDN Without DNS
resource "aws_cloudfront_distribution" "cdn_static_site_default_cert" {
  count               = var.aws_spa_cdn_enabled ? ( local.selected_arn == "" ? 1 : 0 ) : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.aws_spa_root_object 
  comment             = "CDN for ${var.aws_spa_website_bucket_name} static"

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

  viewer_certificate {
    cloudfront_default_certificate = true 
  }
}

### CDN with custom DNS
resource "aws_cloudfront_distribution" "cdn_static_site" {
  count               = var.aws_spa_cdn_enabled ? ( local.selected_arn != "" ? 1 : 0 ) : 0
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = var.aws_spa_root_object 
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

  aliases = [ var.aws_r53_root_domain_deploy ? "${var.aws_r53_domain_name}" : "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}" ]

  viewer_certificate {
    acm_certificate_arn      = local.selected_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}


locals {
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

##### ALL DNS

## Set domain to be used
data "aws_route53_zone" "selected" {
  count        = var.aws_r53_domain_name != "" ? 1 : 0
  name         = "${var.aws_r53_domain_name}."
  private_zone = false
}
###

## RECORDS
# Create sub-domain record
resource "aws_route53_record" "dev" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 0 : 1) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
  type    = "A"

  alias {
    name                   = local.r53_alias_name
    zone_id                = local.r53_alias_id
    evaluate_target_health = false
  }
}

# Create both www and root records when deploying at root level
resource "aws_route53_record" "root-a" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 1 : 0) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = var.aws_r53_domain_name
  type    = "A"

  alias {
    name                   = local.r53_alias_name
    zone_id                = local.r53_alias_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www-a" {
  count   = local.fqdn_provided ? (var.aws_r53_root_domain_deploy ? 1 : 0) : 0
  zone_id = data.aws_route53_zone.selected[0].zone_id
  name    = "www.{var.aws_r53_domain_name}"
  type    = "A"

  alias {
    name                   = local.r53_alias_name
    zone_id                = local.r53_alias_id
    evaluate_target_health = false
  }
}
###

locals {
  r53_alias_name = var.aws_spa_cdn_enabled ? aws_cloudfront_distribution.cdn_static_site[0].domain_name : aws_s3_bucket_website_configuration.aws_spa_website_bucket.website_domain
  r53_alias_id   = var.aws_spa_cdn_enabled ? aws_cloudfront_distribution.cdn_static_site[0].hosted_zone_id : aws_s3_bucket.aws_spa_website_bucket.hosted_zone_id
}

# CERTIFICATE STUFF

data "aws_acm_certificate" "issued" {
  for_each = local.cert_available ? {
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
###

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
###

### Some locals for parsing details
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

  url = (local.fqdn_provided ?
    (var.aws_r53_root_domain_deploy ?
      "${var.aws_r53_domain_name}" :
      "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
    ) :
    (var.aws_spa_cdn_enabled ? "${local.cdn_site_url}" :
     "${aws_s3_bucket.aws_spa_website_bucket.bucket_regional_domain_name}/${var.aws_spa_root_object}"
    )
  )
  public_url = "https://${local.url}"

  cdn_alias_url = (local.fqdn_provided ?
    (var.aws_r53_root_domain_deploy ?
      "${var.aws_r53_domain_name}" :
      "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
    ) : ""
  )
  
  # This checks if we have the fqdn, and if it should go to the root domain or not.
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

output "public_url" {
  value = local.public_url
}

output "selected_arn" {
  value = local.selected_arn
}