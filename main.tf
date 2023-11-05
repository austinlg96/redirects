data "aws_caller_identity" "current" {}

data "aws_region" "current" {}
module "kms" {
  source       = "./modules/kms_encryption"
  encrypt_arns = [module.create_url.role.arn]
  decrypt_arns = [module.load_url.role.arn]
}
module "create_url" {
  source         = "./modules/lambda"
  name           = "create_url"
  excluded_files = ["__pycache__/", "local_types.py"]
  handler        = "create_url.lambda_handler"
  environment_vars = {
    URL_PREFIX         = "${var.protocol}://${var.domain}/${var.base_path}"
    KMS_ENCRYPTION_KEY = module.kms.key_arn
    DDB_TABLE_NAME     = aws_dynamodb_table.redirects.name
    DEBUGGING          = "False"
  }
}
module "load_url" {
  source         = "./modules/lambda"
  name           = "load_url"
  excluded_files = ["__pycache__/", "local_types.py"]
  handler        = "load_url.lambda_handler"
  environment_vars = {
    KMS_ENCRYPTION_KEY = module.kms.key_arn
    DDB_TABLE_NAME     = aws_dynamodb_table.redirects.name
    DEBUGGING          = "False"
    ERROR_DESTINATION  = var.error_destination
  }
}

module "publish_msg" {
  source         = "./modules/lambda"
  name           = "publish_msg"
  excluded_files = ["local_types.py"]
  handler        = "publish_msg.lambda_handler"
  environment_vars = {
    DEBUGGING     = "False"
    SNS_TOPIC_ARN = aws_sns_topic.page_request.arn
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

resource "aws_api_gateway_integration" "load_url" {
  rest_api_id             = aws_api_gateway_rest_api.redirect.id
  resource_id             = aws_api_gateway_resource.redirect.id
  http_method             = aws_api_gateway_method.get_redirect.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.load_url.function.invoke_arn
}

resource "aws_lambda_permission" "load_url_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.load_url.function.function_name
  principal     = "apigateway.amazonaws.com"

  # TODO: Improve ARN
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.redirect.id}/*/${aws_api_gateway_method.get_redirect.http_method}${aws_api_gateway_resource.redirect.path}"
}

resource "aws_api_gateway_method" "post_redirect" {
  rest_api_id   = aws_api_gateway_rest_api.redirect.id
  resource_id   = aws_api_gateway_resource.redirect.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "create_url" {
  rest_api_id             = aws_api_gateway_rest_api.redirect.id
  resource_id             = aws_api_gateway_resource.redirect.id
  http_method             = aws_api_gateway_method.post_redirect.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.create_url.function.invoke_arn
}

resource "aws_lambda_permission" "create_url_apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.create_url.function.function_name
  principal     = "apigateway.amazonaws.com"

  # TODO: Improve ARN
  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.redirect.id}/*/${aws_api_gateway_method.post_redirect.http_method}${aws_api_gateway_resource.redirect.path}"
}

resource "aws_api_gateway_gateway_response" "default_4xx" {
  status_code   = 307
  rest_api_id   = aws_api_gateway_rest_api.redirect.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Location" : "'${var.error_destination}'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  status_code   = 307
  rest_api_id   = aws_api_gateway_rest_api.redirect.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Location" : "'${var.error_destination}'"
  }
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
  stage_name    = "1"
}

resource "aws_route53_zone" "root" {
  name = "${var.domain}."
}

resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = { for index, option in aws_acm_certificate.cert.domain_validation_options : option.resource_record_name => option }
  name     = each.value.resource_record_name
  type     = each.value.resource_record_type
  zone_id  = aws_route53_zone.root.id
  records  = [each.value.resource_record_value]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for cv in aws_route53_record.cert_validation : cv.fqdn]
}

resource "aws_api_gateway_domain_name" "root" {
  regional_certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
  domain_name              = var.domain

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_route53_record" "root" {
  name    = aws_api_gateway_domain_name.root.domain_name
  type    = "A"
  zone_id = aws_route53_zone.root.id

  alias {
    evaluate_target_health = true
    name                   = aws_api_gateway_domain_name.root.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.root.regional_zone_id
  }
}

resource "aws_api_gateway_base_path_mapping" "main" {
  api_id      = aws_api_gateway_rest_api.redirect.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  domain_name = aws_api_gateway_domain_name.root.domain_name
}

resource "aws_sns_topic" "page_request" {
  name = "redirect-page-request-topic"
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = aws_sns_topic.page_request.arn
  protocol  = var.sns_sub_proto
  endpoint  = var.sns_sub_endpoint
}

resource "aws_dynamodb_table" "redirects" {
  name             = "Redirects"
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
}

data "aws_iam_policy_document" "ddb_put" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.redirects.arn]
  }
}

resource "aws_iam_policy" "ddb_put" {
  name        = "DDB_Put"
  description = "Allows writing redirects to the redirect table."
  policy      = data.aws_iam_policy_document.ddb_put.json
}

resource "aws_iam_role_policy_attachment" "create_fn_ddb" {
  role       = module.create_url.role.name
  policy_arn = aws_iam_policy.ddb_put.arn
}

resource "aws_iam_role_policy_attachment" "load_fn_ddb" {
  role       = module.load_url.role.name
  policy_arn = aws_iam_policy.ddb_put.arn
}

resource "local_file" "local_environment_settings" {
  filename = "./.env"
  content  = <<-EOT
        URL_PREFIX=${var.protocol}://${var.domain}/${var.base_path}
        CREATE_URL_ARN=${module.create_url.function.arn}
        LOAD_URL_ARN=${module.load_url.function.arn}
        KMS_ENCRYPTION_KEY=${module.kms.key_arn}
        DDB_TABLE_NAME=${aws_dynamodb_table.redirects.name}
        EOT
}


data "aws_iam_policy_document" "ddb_stream_read" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams"
    ]
    resources = [aws_dynamodb_table.redirects.stream_arn]
  }
}

resource "aws_iam_policy" "ddb_stream_read" {
  name        = "DDB_Stream_Read"
  description = "Allows reading the redirect table's stream."
  policy      = data.aws_iam_policy_document.ddb_stream_read.json
}

resource "aws_iam_role_policy_attachment" "publish_msg_ddb_stream" {
  role       = module.publish_msg.role.name
  policy_arn = aws_iam_policy.ddb_stream_read.arn
}

resource "aws_lambda_event_source_mapping" "ddb_to_publish_msg" {
  event_source_arn  = aws_dynamodb_table.redirects.stream_arn
  function_name     = module.publish_msg.function.arn
  starting_position = "LATEST"

  depends_on = [
    aws_iam_role_policy_attachment.publish_msg_ddb_stream
  ]
}

data "aws_iam_policy_document" "sns_pub" {
  statement {
    effect = "Allow"
    actions = [
      "SNS:Publish"
    ]
    resources = [aws_sns_topic.page_request.arn]
  }
}

resource "aws_iam_policy" "sns_pub" {
  name        = "SNS_Pub"
  description = "Allows publishing to the SNS stream."
  policy      = data.aws_iam_policy_document.sns_pub.json
}

resource "aws_iam_role_policy_attachment" "publish_msg_sns_topic" {
  role       = module.publish_msg.role.name
  policy_arn = aws_iam_policy.sns_pub.arn
}
