resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "CloudFront OAC"
  origin_access_control_origin_type = "s3"

  signing_behavior = "always"
  signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled = true

  default_root_object = "index.html"

  origin {

    domain_name = "${var.assets_bucket_name}.s3.eu-west-2.amazonaws.com"

    origin_id = "assets"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id

  }

  origin {

    domain_name = "${var.delivery_bucket_name}.s3.eu-west-2.amazonaws.com"

    origin_id = "delivery"

    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id

  }

  default_cache_behavior {

    target_origin_id = "assets"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    compress = true

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  ordered_cache_behavior {

    path_pattern = "/videos/*"

    target_origin_id = "delivery"

    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = [
      "GET",
      "HEAD"
    ]

    cached_methods = [
      "GET",
      "HEAD"
    ]

    compress = false

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

