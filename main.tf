data "aws_caller_identity" "current" {}

resource "aws_kms_key" "url_encryption_key" {
  description             = "Key for encrypting and decrypting url data."
  deletion_window_in_days = 7
}

data "aws_iam_policy_document" "url_encryption_key_policy" {

  statement {
    effect = "Allow"
    principals {
        type = "AWS"
        identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root", data.aws_caller_identity.current.arn]
    }
    sid = "Allow all for root."
    actions = ["kms:*"]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.iam_for_lambda.arn]
    }
    sid = "Allow use of the key."

    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_kms_key_policy" "example" {
  key_id = aws_kms_key.url_encryption_key.id
  policy = data.aws_iam_policy_document.url_encryption_key_policy.json
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "create_url" {
  type        = "zip"
  source_dir = "./aws/create_url"
  excludes = ["./aws/create_url/__pycache__/","./aws/create_url/local_types.py"]
  output_path = "./build/create_url.zip"
}

resource "aws_lambda_function" "create_url" {
  filename      = data.archive_file.create_url.output_path
  function_name = "create_url"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "create_url.lambda_handler"

  source_code_hash = data.archive_file.create_url.output_base64sha256

  runtime = "python3.11"

  environment {
    variables = {
      URL_PREFIX = var.URL_PREFIX
      KMS_ENCRYPTION_KEY = aws_kms_key.url_encryption_key.arn
    }
  }
}
