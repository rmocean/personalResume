variable "bucket_names" {
  type    = list(string)
  default = []
}

resource "aws_s3_bucket" "my_buckets" {
  for_each = toset(var.bucket_names)

  bucket = each.key

  dynamic "validation" {
    for_each = can(data.aws_s3_bucket.existing_buckets[each.key]) ? {} : { "validation" = null }
    content {
      exists = can(data.aws_s3_bucket.existing_buckets[each.key])
    }
  }
}

data "aws_s3_bucket" "existing_buckets" {
  for_each = toset(var.bucket_names)

  bucket = each.value
}
