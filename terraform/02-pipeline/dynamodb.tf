############################################
# DynamoDB Catalog Table
############################################

resource "aws_dynamodb_table" "catalog" {
  name         = "${local.name_prefix}-catalog"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "video_id"

  attribute {
    name = "video_id"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  global_secondary_index {
    name            = "StatusCreatedAtIndex"
    hash_key        = "status"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  tags = {
    Name = "${local.name_prefix}-catalog"
  }
}
