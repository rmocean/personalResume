terraform {
  backend "s3" {
    bucket = "mybucket-rm-backend"
    key    = "mybucket-rm-backend/terraform.tfstate"
    region = "us-east-1"
  }
}
