#DynamoDB creation
resource "aws_dynamodb_table" "visitor_counter" {
  name           = "visitor_counter_table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"  # String type for the hash key
  }
}