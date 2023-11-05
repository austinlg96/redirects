data "aws_iam_policy_document" "main" {
  dynamic "statement" {
    for_each = var.statements
    content {
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "main" {
  name        = var.name
  description = var.description
  policy      = data.aws_iam_policy_document.main.json
}

resource "aws_iam_role_policy_attachment" "main" {
  for_each   = toset(var.role_names)
  role       = each.key
  policy_arn = aws_iam_policy.main.arn
}
