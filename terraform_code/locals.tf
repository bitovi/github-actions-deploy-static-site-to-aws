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

  ### Amazon buckets have a limit of 63 chars.
  ### IF we are hosting a site with a DNS name and without CDN, bucket name *MUST* match DNS name. Hence the 63 chars limit.
  ### IF the provided length exceeds the limit, we will shorten it until it fits.
  ### BUT if CDN is enabled, we don't have that 63 limit, so any sub-domain can be used, or the default aws_resource_identifier will be.

  # IF FQDN bucket length exceeds 63 chars, will use default identifier
  s3_bucket_name = local.fqdn_provided ? local.r53_fqdn : local.s3_default_name

  s3_default_name = var.aws_site_bucket_name != "" ? (length(var.aws_site_bucket_name) < 63 ? var.aws_site_bucket_name : "${var.aws_resource_identifier}-sp") : "${var.aws_resource_identifier}-sp"

  r53_fqdn = var.aws_r53_root_domain_deploy ? var.aws_r53_domain_name : local.fqdn_bucket_name

  fqdn_bucket_name = local.aws_r53_fqdn_full_length > 63 ? local.aws_r53_fqdn_short_length > 63 ? local.aws_r53_fqdn_ss : local.aws_r53_fqdn_short : local.aws_r53_fqdn_full
  # Generate fqdn names
  aws_r53_fqdn_full        = "${var.aws_r53_sub_domain_name}.${var.aws_r53_domain_name}"
  aws_r53_fqdn_short       = "${var.aws_resource_identifier_supershort}.${var.aws_r53_domain_name}"
  # Get lengths of the different bucket names strings
  aws_r53_fqdn_full_length = length(local.aws_r53_fqdn_full)
  aws_r53_fqdn_short_length = length("${var.aws_resource_identifier_supershort}.${var.aws_r53_domain_name}")
  # IF the shortest string is still too long, get how much char's we should remove and do so.
  aws_r53_fqdn_ss_remove = tonumber(local.aws_r53_fqdn_short_length - 63 > 0 ? local.aws_r53_fqdn_short_length - 63 : 0)
  aws_r53_fqdn_ss        = substr(local.aws_r53_fqdn_short, 0, local.aws_r53_fqdn_ss_remove)

  # Final URL Generator
  cdn_site_url = var.aws_site_cdn_enabled ? (local.selected_arn != "" ? coalesce(aws_cloudfront_distribution.cdn_static_site[0].aliases...) : aws_cloudfront_distribution.cdn_static_site_default_cert[0].domain_name) : ""
  # Set to shorten url variable
  s3_endpoint = aws_s3_bucket_website_configuration.aws_site_website_bucket.website_endpoint

  url = var.aws_site_cdn_enabled ? local.cdn_site_url : (local.fqdn_provided ? local.r53_fqdn : local.s3_endpoint)

  protocol = local.cert_available ? (var.aws_site_cdn_enabled ? "https://" : "http://") : "http://"

  public_url = "${local.protocol}${local.url}"
}

output "selected_arn" {
  value       = local.selected_arn
  description = "The ARN of the selected certificate"
}

output "bucket_url" {
  value       = aws_s3_bucket.aws_site_website_bucket.bucket_regional_domain_name
  description = "The S3 bucket regional domain name"
}

output "cloudfront_url" {
  value       = local.cdn_site_url
  description = "The CloudFront distribution URL"
}

output "public_url" {
  value       = local.public_url
  description = "The public URL for the deployed site"
}
