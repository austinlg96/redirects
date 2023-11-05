data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "main" {
  statement {
    sid    = "Allow all."
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.management_arns != null ? var.management_arns : [data.aws_caller_identity.current.arn]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow encrypting data."
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.encrypt_arns
    }
    actions = [
      "kms:Encrypt",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    sid    = "Allow decrypting data."
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = var.decrypt_arns
    }
    actions = [
      "kms:Decrypt",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_kms_key_policy" "main" {
  key_id = aws_kms_key.main.id
  policy = data.aws_iam_policy_document.main.json
}

resource "aws_kms_key" "main" {
  description             = "Key for encrypting and decrypting url data."
  deletion_window_in_days = 7
}
