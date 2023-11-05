

resource "aws_sns_topic" "main" {
  name = var.name
}

module "publish_perms" {
  source      = "../policy_attachment"
  name        = "SNS_Pub"
  description = "Allows publishing to the SNS stream."
  role_names  = var.publish_message_role_names
  statements = [
    {
      effect = "Allow"
      actions = [
        "SNS:Publish"
      ]
      resources = [aws_sns_topic.main.arn]
    }
  ]
}
