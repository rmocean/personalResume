#create unique S3 bucket


/*
module "s3_buckets" {
  source = ".//s3_buckets"
  bucket_names = ["radumocean.com"]
}
*/
#try this approach after I turn on the public access to the bucket
/*resource "aws_s3_bucket_policy" "bucket_policy" {
  for_each = module.s3_buckets.my_buckets

  bucket = each.value.bucket
  policy = file("${path.module}/s3_bucket_policy.json")
}*/
resource "aws_s3_bucket" "bucket" {
  bucket = "radumocean.com"
}

#define bucket policy
/*resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "PublicReadGetObject",
          "Effect" : "Allow",
          "Principal" : "*",
          "Action" : "s3:GetObject",
          "Resource" : "arn:aws:s3:::${aws_s3_bucket.bucket.id}/*"
        }
      ]
    }
  )
}*/

resource "aws_s3_object" "file" {
  for_each = {
    for file in fileset(path.module, "static-website/**/*") : file => file
    if file != "static-website/index.html"
  }
  bucket       = aws_s3_bucket.bucket.id
  key          = replace(each.value, "/^static-website//", "")
  source       = each.value
  content_type = lookup(local.content_types, regex("\\.[^.]+$", each.value), null)
  etag         = filemd5(each.value)
}

resource "aws_s3_object" "index_file" {
  bucket = aws_s3_bucket.bucket.id
  key    = "index.html"
  content = templatefile("${path.module}/static-website/index.html", {
    visitor_counter_url = aws_lambda_function_url.visitor_counter_url.function_url
  })
  content_type = "text/html"
  etag = md5(templatefile("${path.module}/static-website/index.html", {
    visitor_counter_url = aws_lambda_function_url.visitor_counter_url.function_url
  }))
}

resource "aws_s3_bucket_website_configuration" "hosting" {
  bucket = aws_s3_bucket.bucket.id

  index_document {
    suffix = "index.html"
  }
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = var.cloudfront_aliases

  origin {
    domain_name = aws_s3_bucket_website_configuration.hosting.website_endpoint
    origin_id   = aws_s3_bucket.bucket.bucket_regional_domain_name

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  default_cache_behavior {
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.bucket.bucket_regional_domain_name
  }
}

data "archive_file" "visitor_counter_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/visitor_counter.py"
  output_path = "${path.module}/lambda/visitor_counter.zip"
}

resource "aws_iam_role" "visitor_counter_lambda_role" {
  name = "visitor-counter-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "visitor_counter_lambda_basic" {
  role       = aws_iam_role.visitor_counter_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "visitor_counter_dynamodb_policy" {
  name = "visitor-counter-dynamodb-policy"
  role = aws_iam_role.visitor_counter_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.visitor_counter.arn
      }
    ]
  })
}

resource "aws_lambda_function" "visitor_counter" {
  function_name    = "visitor-counter"
  role             = aws_iam_role.visitor_counter_lambda_role.arn
  handler          = "visitor_counter.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.visitor_counter_zip.output_path
  source_code_hash = data.archive_file.visitor_counter_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_counter.name
    }
  }
}

resource "aws_lambda_function_url" "visitor_counter_url" {
  function_name      = aws_lambda_function.visitor_counter.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["content-type"]
    max_age       = 86400
  }
}

resource "aws_lambda_permission" "visitor_counter_function_url_permission" {
  statement_id           = "AllowPublicFunctionUrlInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.visitor_counter.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "visitor_counter_invoke_from_url_permission" {
  statement_id  = "AllowPublicInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "*"
}

