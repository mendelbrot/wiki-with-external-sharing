provider "aws" {
  region = "us-west-2"
}

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
