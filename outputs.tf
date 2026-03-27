output "website_url" {
  description = "Website URL (HTTPS)"
  value       = aws_cloudfront_distribution.distribution.domain_name
}

output "s3_url" {
  description = "S3 hosting URL (HTTP)"
  value       = aws_s3_bucket_website_configuration.hosting.website_endpoint
}

output "visitor_counter_url" {
  description = "Public Lambda Function URL for the visitor counter"
  value       = aws_lambda_function_url.visitor_counter_url.function_url
}
