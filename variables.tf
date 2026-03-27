variable "cloudfront_aliases" {
  description = "Custom domain names to attach to the CloudFront distribution."
  type        = list(string)
  default     = ["radumocean.com"]
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for the CloudFront aliases."
  type        = string
}
