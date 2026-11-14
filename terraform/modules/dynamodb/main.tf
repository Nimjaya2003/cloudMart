resource "aws_dynamodb_table" "carts" {
  name         = "${var.name}-carts" # the cart service's default CART_TABLE
  billing_mode = "PAY_PER_REQUEST"   # no capacity to size, and no cost while idle
  hash_key     = "cart_id"
  range_key    = "product_id"

  attribute {
    name = "cart_id"
    type = "S"
  }

  attribute {
    name = "product_id"
    type = "S"
  }
}