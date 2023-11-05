locals {
  default_lambda_dir = "./aws/"
  source_dir         = var.source_dir != null ? var.source_dir : "${local.default_lambda_dir}/${var.name}"
  build_path         = var.build_path != null ? var.build_path : "./build/lambda/${var.name}.zip"
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

resource "aws_iam_role" "main" {
  name               = "iam_for_${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = local.source_dir
  excludes    = var.excluded_files
  output_path = local.build_path
}

resource "aws_lambda_function" "main" {
  filename      = data.archive_file.source.output_path
  function_name = var.name
  role          = aws_iam_role.main.arn
  handler       = var.handler

  source_code_hash = data.archive_file.source.output_base64sha256

  runtime = "python3.11"

  environment {
    variables = var.environment_vars
  }
}
