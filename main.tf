data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

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
      identifiers = [aws_iam_role.iam_for_create_url.arn, aws_iam_role.iam_for_load_url.arn]
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

# Generic Lambda resources

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

# Create URL Function

resource "aws_iam_role" "iam_for_create_url" {
  name               = "iam_for_create_url"
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
  role          = aws_iam_role.iam_for_create_url.arn
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


# Load URL Function

resource "aws_iam_role" "iam_for_load_url" {
  name               = "iam_for_load_url"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "load_url" {
  type        = "zip"
  source_dir = "./aws/load_url"
  excludes = ["./aws/load_url/__pycache__/","./aws/load_url/local_types.py"]
  output_path = "./build/load_url.zip"
}

resource "aws_lambda_function" "load_url" {
  filename      = data.archive_file.load_url.output_path
  function_name = "load_url"
  role          = aws_iam_role.iam_for_load_url.arn
  handler       = "load_url.lambda_handler"

  source_code_hash = data.archive_file.load_url.output_base64sha256

  runtime = "python3.11"

  environment {
    variables = {
      KMS_ENCRYPTION_KEY = aws_kms_key.url_encryption_key.arn
    }
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "redirect" {
  name = "URL Redirect"
}

resource "aws_api_gateway_resource" "redirect" {
  path_part   = "redirect"
  parent_id   = aws_api_gateway_rest_api.redirect.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.redirect.id
}

resource "aws_api_gateway_method" "get_redirect" {
  rest_api_id   = aws_api_gateway_rest_api.redirect.id
  resource_id   = aws_api_gateway_resource.redirect.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_url" {
  rest_api_id             = aws_api_gateway_rest_api.redirect.id
  resource_id             = aws_api_gateway_resource.redirect.id
  http_method             = aws_api_gateway_method.get_redirect.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.load_url.invoke_arn
}

# Lambda
resource "aws_lambda_permission" "create_url_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.load_url.function_name
  principal     = "apigateway.amazonaws.com"

  # TODO: Improve ARN
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.redirect.id}/*/${aws_api_gateway_method.get_redirect.http_method}${aws_api_gateway_resource.redirect.path}"
}

resource "aws_api_gateway_deployment" "redirect" {
  rest_api_id = aws_api_gateway_rest_api.redirect.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.redirect.id
  rest_api_id   = aws_api_gateway_rest_api.redirect.id
  stage_name    = ""
}
