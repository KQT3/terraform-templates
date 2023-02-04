terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

/* -------------------------------------------------- S3 Bucket ----------------------------------------------------- */

resource "aws_s3_bucket" "www_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_policy" "www_bucket" {
  bucket = aws_s3_bucket.www_bucket.bucket

  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Sid       = "PublicReadAccess",
          Effect    = "Allow",
          Principal = "*",
          Action    = "s3:GetObject",
          Resource  = "arn:aws:s3:::${aws_s3_bucket.www_bucket.bucket}/*",
          Condition = {
            StringEquals = {
              "aws:UserAgent" : "Amazon CloudFront"
            }
          }
        }
      ]
    }
  )
}

resource "aws_s3_bucket_website_configuration" "www_bucket" {
  bucket = aws_s3_bucket.www_bucket.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

/* -------------------------------------------------- Cloudfront ---------------------------------------------------- */

locals {
  s3_origin_id = aws_s3_bucket.www_bucket.bucket_domain_name
}

data "aws_cloudfront_origin_request_policy" "this" {
  name = "Managed-CORS-S3Origin"
}

data "aws_cloudfront_cache_policy" "this" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.www_bucket.website_endpoint
    origin_id   = local.s3_origin_id
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

  }

  enabled         = true
  is_ipv6_enabled = true
  comment         = var.cloudfront_alternative_domain_name

  aliases = [var.cloudfront_alternative_domain_name]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.this.id
    cache_policy_id          = data.aws_cloudfront_cache_policy.this.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    acm_certificate_arn      = var.cloudfront_acm_certificate
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

/* -------------------------------------------------- Route53 ------------------------------------------------------- */

resource "aws_route53_record" "www" {
  zone_id = var.route53_zone_id
  name    = var.cloudfront_alternative_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}

/* -------------------------------------------------- IAM ----------------------------------------------------------- */

resource "aws_iam_user" "user" {
  name = "s3.${var.cloudfront_alternative_domain_name}"
}

resource "aws_iam_group" "group" {
  name = "s3.${var.cloudfront_alternative_domain_name}"
}

resource "aws_iam_group_membership" "group_membership" {
  name  = "s3.${var.cloudfront_alternative_domain_name}"
  users = [aws_iam_user.user.name]
  group = aws_iam_group.group.name
}

resource "aws_iam_policy" "cloudfront_policy" {
  name = "allow-cloudfront-${var.cloudfront_alternative_domain_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "VisualEditor0",
        Effect   = "Allow",
        Action   = "cloudfront:CreateInvalidation",
        Resource = "arn:aws:cloudfront:::distribution/"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_policy" {
  name = "allow-s3-${var.cloudfront_alternative_domain_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*",
          "s3-object-lambda:*"
        ]
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.www_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.www_bucket.bucket}/*"
        ]
      },
    ]
  })
}

resource "aws_iam_group_policy_attachment" "cloudfront_policy_attachment" {
  group      = aws_iam_group.group.name
  policy_arn = aws_iam_policy.cloudfront_policy.arn
}

resource "aws_iam_group_policy_attachment" "s3_policy_attachment" {
  group      = aws_iam_group.group.name
  policy_arn = aws_iam_policy.s3_policy.arn
}
