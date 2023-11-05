resource "aws_dynamodb_table" "main" {
  name             = var.name
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "HK"
  range_key        = "SK"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "HK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}

module "put_item_perms" {
  source      = "../policy_attachment"
  name        = "DDB_Put"
  description = "Allows adding items to the table."
  role_names  = var.put_item_role_names
  statements = [
    {
      effect    = "Allow"
      actions   = ["dynamodb:PutItem"]
      resources = [aws_dynamodb_table.main.arn]
    }
  ]
}

module "stream_table_perms" {
  source      = "../policy_attachment"
  name        = "DDB_Stream_Read"
  description = "Allows streaming the table changes."
  role_names  = var.stream_table_role_names
  statements = [
    {
      effect = "Allow"
      actions = [
        "dynamodb:GetRecords",
        "dynamodb:GetShardIterator",
        "dynamodb:DescribeStream",
        "dynamodb:ListStreams"
      ]
      resources = [aws_dynamodb_table.main.stream_arn]
    }
  ]
}
