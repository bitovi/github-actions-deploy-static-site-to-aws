### Site Bucket
## Main bucket
resource "aws_s3_bucket" "aws_site_website_bucket" {
  bucket = local.s3_bucket_name
}
## Bucket website config
resource "aws_s3_bucket_website_configuration" "aws_site_website_bucket" {
  bucket = aws_s3_bucket.aws_site_website_bucket.id
  index_document {
    suffix = var.aws_site_root_object
  }

  error_document {
    key = var.aws_site_error_document
  }
}

## Only create this two IF -> R53 FQDN provided and CDN is off - for www.* support
resource "aws_s3_bucket" "aws_site_website_bucket_www" {
  count  = var.aws_site_cdn_enabled ? 0 : var.aws_r53_root_domain_deploy ? 1 : 0 
  bucket = "www.${local.s3_bucket_name}"
}

resource "aws_s3_bucket_website_configuration" "aws_site_website_bucket_www" {
  count  = var.aws_site_cdn_enabled ? 0 : var.aws_r53_root_domain_deploy ? 1 : 0 
  bucket = aws_s3_bucket.aws_site_website_bucket_www[0].id
  redirect_all_requests_to {
    host_name = local.s3_bucket_name
  }
}

# Allow public access to bucket
resource "aws_s3_bucket_public_access_block" "aws_site_website_bucket" {
  bucket                  = aws_s3_bucket.aws_site_website_bucket.id
  block_public_policy     = false
  restrict_public_buckets = false
  depends_on = [ aws_s3_bucket.aws_site_website_bucket ]
}
## Same, but if www bucket is created
resource "aws_s3_bucket_public_access_block" "aws_site_website_bucket_www" {
  count  = var.aws_site_cdn_enabled ? 0 : var.aws_r53_root_domain_deploy ? 1 : 0 
  bucket                  = aws_s3_bucket.aws_site_website_bucket_www[0].id
  block_public_policy     = false
  restrict_public_buckets = false
  depends_on = [ aws_s3_bucket.aws_site_website_bucket_www ]
}

# Tool to identify file types
module "template_files" {
  source   = "hashicorp/dir/template"
  base_dir = var.aws_site_source_folder
}

# Will upload each file to the bucket, defining content-type
resource "aws_s3_object" "aws_site_website_bucket" {
  for_each = module.template_files.files

  bucket       = aws_s3_bucket.aws_site_website_bucket.id
  key          = each.key
  content_type = contains([".ts", "tsx"], substr(each.key, -3, 3)) ? "text/javascript" : each.value.content_type # Ensuring .ts and .tsx files are set to text/javascript

  source  = each.value.source_path
  content = each.value.content

  etag = each.value.digests.md5
}

### IAM Policies definitions
data "aws_iam_policy_document" "aws_site_bucket_public_access_dns" {
  count = var.aws_site_cdn_enabled ? 0 : 1
  statement {
    actions = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.aws_site_website_bucket.arn}/*"]
    principals {
      identifiers = ["*"]
      type = "AWS"
    }
  }
  depends_on = [ aws_s3_bucket_public_access_block.aws_site_website_bucket ]
}

# Policy failed due to bucket not fully created. Added this delay for it. 
resource "null_resource" "delay" {
  count = var.aws_site_cdn_enabled ? 0 : 1
  triggers = {
    # Using a constant to create a trigger that always changes
    always_run = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "sleep 1"
  }
}

resource "aws_s3_bucket_policy" "aws_site_website_bucket_policy_dns" {
  count = var.aws_site_cdn_enabled ? 0 : 1
  bucket = aws_s3_bucket.aws_site_website_bucket.id
  policy = data.aws_iam_policy_document.aws_site_bucket_public_access_dns[0].json
  depends_on = [
    aws_s3_bucket_public_access_block.aws_site_website_bucket,
    aws_s3_bucket.aws_site_website_bucket,
    null_resource.delay,
  ]
}


### Special policies if CDN is the exposed URL
data "aws_iam_policy_document" "aws_site_website_bucket" {
  count = var.aws_site_cdn_enabled ? 1 : 0
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.aws_site_website_bucket.arn}/*"]
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
  depends_on = [ aws_s3_bucket_public_access_block.aws_site_website_bucket ]
}

resource "aws_s3_bucket_policy" "aws_site_website_bucket_policy" {
  count  = var.aws_site_cdn_enabled ? 1 : 0
  bucket = aws_s3_bucket.aws_site_website_bucket.id
  policy = data.aws_iam_policy_document.aws_site_website_bucket[0].json
  depends_on = [ aws_s3_bucket_public_access_block.aws_site_website_bucket ]
}


### CDN 

### CDN Without DNS
resource "aws_cloudfront_distribution" "cdn_static_site_default_cert" {
  count               = var.aws_site_cdn_enabled ? ( local.cert_available ? 0 : 1 ) : 0
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
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
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
  count               = var.aws_site_cdn_enabled ? ( local.cert_available ? 1 : 0 ) : 0
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
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
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
  
  aliases = [ var.aws_r53_root_domain_deploy ? "${var.aws_r53_domain_name}" : "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}" ]

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
  name    = var.aws_site_cdn_enabled ? "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}" : local.r53_fqdn
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
  name    = "www.${var.aws_r53_domain_name}"
  type    = "A"

  alias {
    name                   = local.r53_alias_name
    zone_id                = local.r53_alias_id
    evaluate_target_health = false
  }
}
###

locals {
  r53_alias_name = var.aws_site_cdn_enabled ? try(aws_cloudfront_distribution.cdn_static_site[0].domain_name,"") : aws_s3_bucket_website_configuration.aws_site_website_bucket.website_domain
  r53_alias_id   = var.aws_site_cdn_enabled ? try(aws_cloudfront_distribution.cdn_static_site[0].hosted_zone_id,"") : aws_s3_bucket.aws_site_website_bucket.hosted_zone_id
}

# CERTIFICATE STUFF

data "aws_acm_certificate" "issued" {
  for_each = local.cert_available && local.fqdn_provided ? {
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
    var.aws_r53_enable_cert && local.fqdn_provided ? 
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
    var.aws_r53_enable_cert && local.fqdn_provided ?
    (var.aws_r53_cert_arn != "" ? true :
      (!var.aws_r53_create_root_cert ?
        (!var.aws_r53_create_sub_cert ?
          (local.fqdn_provided ? true : false)
          : true
        ) : true
      )
    ) : false
  )
  fqdn_provided = (
    (var.aws_r53_domain_name != "") ?
    (var.aws_r53_sub_domain_name != "" ?
      true :
      var.aws_r53_root_domain_deploy ? true : false
    ) : 
    false
  )

  ### Converting JSON to map of strings as GH Actions don't accept map of strings
  aws_site_cdn_custom_error_codes = jsondecode(var.aws_site_cdn_custom_error_codes)

  ### Try looking up for the cert with different names
  acm_arn = try(data.aws_acm_certificate.issued["domain"].arn, try(data.aws_acm_certificate.issued["wildcard"].arn, data.aws_acm_certificate.issued["sub"].arn, ""))

  ### Amazon buckets have a limit of 63 chars. 
  ### IF we are hosting a site with a DNS name and without CDN, bucket name *MUST* match DNS name. Hence the 63 chars limit.
  ### IF the provided length exceeds the limit, we will shorten it until it fits.
  ### BUT if CDN is enabled, we don't have that 63 limit, so any sub-domain can be used, or the default aws_resource_identifier will be. 

  # IF FQDN bucket length exceeds 63 chars, will use default identifier
  s3_bucket_name = local.fqdn_provided ? local.r53_fqdn : local.s3_default_name
  
  s3_default_name = var.aws_site_bucket_name != "" ? ( length(var.aws_site_bucket_name) < 63 ? var.aws_site_bucket_name : "${var.aws_resource_identifier}-sp") : "${var.aws_resource_identifier}-sp"

  r53_fqdn = var.aws_r53_root_domain_deploy ? var.aws_r53_domain_name : local.fqdn_bucket_name

  fqdn_bucket_name = local.aws_r53_fqdn_full_length > 63 ? local.aws_r53_fqdn_short_length > 63 ? local.aws_r53_fqdn_ss : local.aws_r53_fqdn_short : local.aws_r53_fqdn_full
  # Generate fqdn names
  aws_r53_fqdn_full  = "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
  aws_r53_fqdn_short = "${var.aws_resource_identifier_supershort}.${var.aws_r53_domain_name}"
  # Get lengths of the different bucket names strings
  aws_r53_fqdn_full_length = length(local.aws_r53_fqdn_full)
  aws_r53_fqdn_short_length = length("${var.aws_resource_identifier_supershort}.${var.aws_r53_domain_name}")
  # IF the shortest string is still too long, get how much char's we should remove and do so.
  aws_r53_fqdn_ss_remove = tonumber( local.aws_r53_fqdn_short_length - 63 > 0 ? local.aws_r53_fqdn_short_length - 63 : 0 )
  aws_r53_fqdn_ss = substr(local.aws_r53_fqdn_short, 0, local.aws_r53_fqdn_ss_remove)
  ####

  # Final URL Generator
  cdn_site_url = var.aws_site_cdn_enabled ? ( local.selected_arn != "" ? coalesce(aws_cloudfront_distribution.cdn_static_site[0].aliases...) : aws_cloudfront_distribution.cdn_static_site_default_cert[0].domain_name ) : ""
  # Set to shorten url variable
  s3_endpoint = aws_s3_bucket_website_configuration.aws_site_website_bucket.website_endpoint

  #url = local.fqdn_provided ? local.r53_fqdn : (var.aws_site_cdn_enabled ? local.cdn_site_url : local.s3_endpoint )

  url = var.aws_site_cdn_enabled ? local.cdn_site_url : ( local.fqdn_provided ? local.r53_fqdn : local.s3_endpoint )

  protocol = local.cert_available ? ( var.aws_site_cdn_enabled ?  "https://" : "http://" ) : "http://" 

  public_url = "${local.protocol}${local.url}"
}

output "selected_arn" {
  value = local.selected_arn
}

output "bucket_url" {
  value = aws_s3_bucket.aws_site_website_bucket.bucket_regional_domain_name
}

output "cloudfront_url" {
  value = local.cdn_site_url
}

output "public_url" {
  value = local.public_url
}
