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

resource "aws_s3_bucket" "int_wiki" {
  bucket = "mh-int-wiki"
}

data "aws_iam_policy_document" "s3_allow_lambda" {
  statement {
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
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

resource "aws_s3_bucket_policy" "s3_allow_lambda" {
  bucket = aws_s3_bucket.int_wiki.id
  policy = data.aws_iam_policy_document.s3_allow_lambda.json
}

resource "aws_s3_bucket_website_configuration" "int_wiki" {
  bucket = aws_s3_bucket.int_wiki.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

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
