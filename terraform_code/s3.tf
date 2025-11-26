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

  dynamic "error_document" {
    for_each = var.aws_site_error_document != "" ? [1] : []
    content {
      key = var.aws_site_error_document
    }
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
  depends_on              = [aws_s3_bucket.aws_site_website_bucket]
}
## Same, but if www bucket is created
resource "aws_s3_bucket_public_access_block" "aws_site_website_bucket_www" {
  count                   = var.aws_site_cdn_enabled ? 0 : var.aws_r53_root_domain_deploy ? 1 : 0
  bucket                  = aws_s3_bucket.aws_site_website_bucket_www[0].id
  block_public_policy     = false
  restrict_public_buckets = false
  depends_on              = [aws_s3_bucket.aws_site_website_bucket_www]
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

  metadata = var.aws_site_cdn_default_ttl > 0 ? {
    "Cache-Control" = "public, max-age=${var.aws_site_cdn_default_ttl}"
  } : null
}

### IAM Policies definitions
data "aws_iam_policy_document" "aws_site_bucket_public_access_dns" {
  count = var.aws_site_cdn_enabled ? 0 : 1
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.aws_site_website_bucket.arn}/*"]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
  }
  depends_on = [aws_s3_bucket_public_access_block.aws_site_website_bucket]
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
  count  = var.aws_site_cdn_enabled ? 0 : 1
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
  depends_on = [aws_s3_bucket_public_access_block.aws_site_website_bucket]
}

resource "aws_s3_bucket_policy" "aws_site_website_bucket_policy" {
  count      = var.aws_site_cdn_enabled ? 1 : 0
  bucket     = aws_s3_bucket.aws_site_website_bucket.id
  policy     = data.aws_iam_policy_document.aws_site_website_bucket[0].json
  depends_on = [aws_s3_bucket_public_access_block.aws_site_website_bucket]
}
