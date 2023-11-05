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
    DDB_TABLE_NAME     = module.ddb.table.name
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
    DDB_TABLE_NAME     = module.ddb.table.name
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
    SNS_TOPIC_ARN = module.sns.topic.arn
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
  response_templates = {
    "application/json" = "{\"message\":\"redirecting\"}"
  }
  response_parameters = {
    "gatewayresponse.header.Location" : "'${var.error_destination}'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  status_code   = 307
  rest_api_id   = aws_api_gateway_rest_api.redirect.id
  response_type = "DEFAULT_5XX"
  response_templates = {
    "application/json" = "{\"message\":\"redirecting\"}"
  }
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

module "dns" {
  source       = "./modules/dns"
  domain       = var.domain
  name_servers = aws_route53_zone.root.name_servers
}

resource "aws_api_gateway_domain_name" "root" {
  regional_certificate_arn = module.acm.certificate.arn
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

module "sns" {
  source                     = "./modules/sns"
  name                       = "redirect-page-request-topic"
  publish_message_role_names = [module.publish_msg.role.name]
}
resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = module.sns.topic.arn
  protocol  = var.sns_sub_proto
  endpoint  = var.sns_sub_endpoint
}
resource "local_file" "local_environment_settings" {
  filename = "./.env"
  content  = <<-EOT
        URL_PREFIX=${var.protocol}://${var.domain}/${var.base_path}
        CREATE_URL_ARN=${module.create_url.function.arn}
        LOAD_URL_ARN=${module.load_url.function.arn}
        KMS_ENCRYPTION_KEY=${module.kms.key_arn}
        DDB_TABLE_NAME=${module.ddb.table.name}
        EOT
}
resource "aws_lambda_event_source_mapping" "ddb_to_publish_msg" {
  event_source_arn  = module.ddb.table.stream_arn
  function_name     = module.publish_msg.function.arn
  starting_position = "LATEST"

  depends_on = [
    module.ddb
  ]
}

module "acm" {
  source  = "./modules/certificate_manager"
  domain  = var.domain
  zone_id = aws_route53_zone.root.zone_id
}

module "ddb" {
  source                  = "./modules/ddb"
  name                    = "Requests"
  put_item_role_names     = [module.load_url.role.name, module.create_url.role.name]
  stream_table_role_names = [module.publish_msg.role.name]
}
