terraform {
  backend "s3" {
    bucket = "mybucket-rm-backend"
    key    = "s3://mybucket-rm-backend"
    region = "us-east-1"
  }
}
