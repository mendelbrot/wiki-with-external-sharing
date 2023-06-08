provider "aws" {
  region = "us-east-1"
}

# common resources

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


# external wiki

## s3 bucket - ext

resource "aws_s3_bucket" "wiki_ext" {
  bucket = "wiki-ext"
}

data "aws_iam_policy_document" "s3_cloudfront_policy_ext" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.wiki_ext.arn,
      "${aws_s3_bucket.wiki_ext.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "s3_policy_ext" {
  bucket = aws_s3_bucket.wiki_ext.id
  policy = data.aws_iam_policy_document.s3_cloudfront_policy_ext.json
}

module "wiki_ext_files" {
  source   = "hashicorp/dir/template"
  base_dir = "${path.module}/_ext_out"
}

resource "aws_s3_object" "wiki_ext" {
  for_each = module.wiki_ext_files.files

  bucket       = aws_s3_bucket.wiki_ext.id
  key          = each.key
  content_type = each.value.content_type
  source       = each.value.source_path
  content      = each.value.content
  etag         = each.value.digests.md5
}

## cloudfront - ext

locals {
  wiki_ext_origin_id = "wiki_ext_origin_id"
}

resource "aws_cloudfront_distribution" "cloudfront_ext" {
  origin {
    domain_name              = aws_s3_bucket.wiki_ext.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.wiki_ext_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.wiki_ext_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
}


# internal wiki

## s3 bucket - int

resource "aws_s3_bucket" "wiki_int" {
  bucket = "wiki-int"
}

data "aws_iam_policy_document" "s3_cloudfront_policy_int" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.wiki_int.arn,
      "${aws_s3_bucket.wiki_int.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "s3_policy_int" {
  bucket = aws_s3_bucket.wiki_int.id
  policy = data.aws_iam_policy_document.s3_cloudfront_policy_int.json
}

module "wiki_int_files" {
  source   = "hashicorp/dir/template"
  base_dir = "${path.module}/_int_out"
}

resource "aws_s3_object" "wiki_int" {
  for_each = module.wiki_int_files.files

  bucket       = aws_s3_bucket.wiki_int.id
  key          = each.key
  content_type = each.value.content_type
  source       = each.value.source_path
  content      = each.value.content
  etag         = each.value.digests.md5
}

## authorizer lambda - int

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/authorizer.js"
  output_path = "${path.module}/authorizer.zip"
}

resource "aws_lambda_function" "authorizer" {
  filename         = "${path.module}/authorizer.zip"
  function_name    = "authorizer"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "authorizer.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "nodejs18.x"
  publish          = true
}

## cloudfront - int

locals {
  wiki_int_origin_id = "wiki_int_origin_id"
}

resource "aws_cloudfront_distribution" "cloudfront_int" {
  origin {
    domain_name              = aws_s3_bucket.wiki_int.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.wiki_int_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  custom_error_response {
    error_caching_min_ttl = 10
    error_code            = 404
    response_code         = 404
    response_page_path    = "/404.html"
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.wiki_int_origin_id

    lambda_function_association {
      event_type = "viewer-request"
      lambda_arn   = aws_lambda_function.authorizer.qualified_arn
      include_body = false
    }

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
}
