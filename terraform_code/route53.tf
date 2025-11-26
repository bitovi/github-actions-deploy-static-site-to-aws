##### ALL DNS

## Set domain to be used
data "aws_route53_zone" "selected" {
  count        = var.aws_r53_domain_name != "" ? 1 : 0
  name         = "${var.aws_r53_domain_name}."
  private_zone = false
}

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

locals {
  r53_alias_name = var.aws_site_cdn_enabled ? try(aws_cloudfront_distribution.cdn_static_site[0].domain_name, "") : aws_s3_bucket_website_configuration.aws_site_website_bucket.website_domain
  r53_alias_id   = var.aws_site_cdn_enabled ? try(aws_cloudfront_distribution.cdn_static_site[0].hosted_zone_id, "") : aws_s3_bucket.aws_site_website_bucket.hosted_zone_id
}
