provider "aws" {
  region = "us-west-2"
}


# external wiki
# http://mh-ext-wiki.s3-website-us-west-2.amazonaws.com/

resource "aws_s3_bucket" "ext_wiki" {
  bucket = "mh-ext-wiki"
}

resource "aws_s3_bucket_public_access_block" "ext_wiki" {
  bucket = aws_s3_bucket.ext_wiki.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "allow_public_access" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.ext_wiki.arn,
      "${aws_s3_bucket.ext_wiki.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.ext_wiki.id
  policy = data.aws_iam_policy_document.allow_public_access.json
}

resource "aws_s3_bucket_website_configuration" "ext_wiki" {
  bucket = aws_s3_bucket.ext_wiki.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

module "ext_wiki_files" {
  source   = "hashicorp/dir/template"
  base_dir = "${path.module}/_ext_out"
}

resource "aws_s3_object" "ext_wiki" {
  for_each = module.ext_wiki_files.files

  bucket       = aws_s3_bucket.ext_wiki.id
  key          = each.key
  content_type = each.value.content_type
  source       = each.value.source_path
  content      = each.value.content
  etag         = each.value.digests.md5
}


# internal wiki

## s3 bucket

resource "aws_s3_bucket" "int_wiki" {
  bucket = "mh-int-wiki"
}

# resource "aws_s3_bucket_public_access_block" "int_wiki" {
#   bucket = aws_s3_bucket.int_wiki.id

#   block_public_acls       = false
#   block_public_policy     = false
#   ignore_public_acls      = false
#   restrict_public_buckets = false
# }

# data "aws_iam_policy_document" "s3_allow_lambda" {
#   statement {
#     principals {
#       type        = "Service"
#       identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
#     }

#     actions = [
#       "s3:GetObject",
#       "s3:ListBucket",
#     ]

#     resources = [
#       aws_s3_bucket.int_wiki.arn,
#       "${aws_s3_bucket.int_wiki.arn}/*",
#     ]
#   }
# }

# resource "aws_s3_bucket_policy" "s3_allow_lambda" {
#   bucket = aws_s3_bucket.int_wiki.id
#   policy = data.aws_iam_policy_document.s3_allow_lambda.json
# }

data "aws_iam_policy_document" "s3_policy_int" {
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
      aws_s3_bucket.int_wiki.arn,
      "${aws_s3_bucket.int_wiki.arn}/*",
    ]
  }
}

resource "aws_s3_bucket_policy" "s3_policy_int" {
  bucket = aws_s3_bucket.int_wiki.id
  policy = data.aws_iam_policy_document.s3_policy_int.json
}

# resource "aws_s3_bucket_website_configuration" "int_wiki" {
#   bucket = aws_s3_bucket.int_wiki.id

#   index_document {
#     suffix = "index.html"
#   }

#   error_document {
#     key = "404.html"
#   }
# }

module "int_wiki_files" {
  source   = "hashicorp/dir/template"
  base_dir = "${path.module}/_int_out"
}

resource "aws_s3_object" "int_wiki" {
  for_each = module.int_wiki_files.files

  bucket       = aws_s3_bucket.int_wiki.id
  key          = each.key
  content_type = each.value.content_type
  source       = each.value.source_path
  content      = each.value.content
  etag         = each.value.digests.md5
}

## authorizer lambda

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
  source_file = "authorizer.js"
  output_path = "authorizer_function_payload.zip"
}

resource "aws_lambda_function" "authorizer" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename         = "authorizer_function_payload.zip"
  function_name    = "authorizer"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "authorizer.handler"
  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "nodejs18.x"
}

## cloudfront

locals {
  s3_origin_id = "S3OriginID"
}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "default"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.int_wiki.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  custom_error_response {
    error_caching_min_ttl =  10
    error_code = 404
    response_code = 404
    response_page_path = "/404.html"
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
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }

      # lambda_function_association {
      #   event_type   = "viewer-request"
      #   lambda_arn   = aws_lambda_function.authorizer.qualified_arn
      #   include_body = false
      # }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
}

## api gateway

# resource "aws_api_gateway_rest_api" "int_wiki" {
#   name = "auth-int-wiki"
# }

# resource "aws_api_gateway_authorizer" "int_wiki" {
#   name                   = "int_wiki"
#   rest_api_id            = aws_api_gateway_rest_api.int_wiki.id
#   authorizer_uri         = aws_lambda_function.authorizer.invoke_arn
#   authorizer_credentials = aws_iam_role.invocation_role.arn
# }

# data "aws_iam_policy_document" "invocation_assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type       = "Service"
#       identifiers = ["apigateway.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "invocation_role" {
#   name               = "api_gateway_auth_invocation"
#   path               = "/"
#   assume_role_policy = data.aws_iam_policy_document.assume_role.json
# }

# data "aws_iam_policy_document" "invocation_policy" {
#   statement {
#     effect    = "Allow"
#     actions   = ["lambda:InvokeFunction"]
#     resources = [aws_lambda_function.authorizer.arn]
#   }
# }

# resource "aws_iam_role_policy" "invocation_policy" {
#   name   = "default"
#   role   = aws_iam_role.invocation_role.id
#   policy = data.aws_iam_policy_document.invocation_policy.json
# }
