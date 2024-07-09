resource "aws_api_gateway_rest_api" "findly_rest_api" {
  name        = "Findly REST API"
  description = "Access RAG endpoints for Findly exercise."
}

resource "aws_api_gateway_resource" "index_url_endpoint" {
  rest_api_id = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.findly_rest_api.root_resource_id}"
  path_part        = "index_url"
}

resource "aws_api_gateway_method" "index_url_endpoint" {
  rest_api_id   = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  resource_id   = "${aws_api_gateway_resource.index_url_endpoint.id}"
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.findly_rest_api.id
  resource_id = aws_api_gateway_resource.index_url_endpoint.id
  http_method = aws_api_gateway_method.index_url_endpoint.http_method
  status_code = "200"
}

resource "aws_api_gateway_integration" "index_url_lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  resource_id = "${aws_api_gateway_method.index_url_endpoint.resource_id}"
  http_method = "${aws_api_gateway_method.index_url_endpoint.http_method}"

  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${var.aws_account}:function:index-url/invocations"
  request_parameters = {
    "integration.request.header.X-Amz-Invocation-Type" = "'Event'"
  }
}

resource "aws_api_gateway_integration_response" "index_url_lambda_response" {
  rest_api_id = aws_api_gateway_rest_api.findly_rest_api.id
  resource_id = aws_api_gateway_resource.index_url_endpoint.id
  http_method = aws_api_gateway_integration.index_url_lambda.http_method
  status_code = "200"
}

resource "aws_lambda_permission" "apigw_index_url" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "index-url"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.findly_rest_api.execution_arn}/*/POST/index_url"
}

resource "aws_api_gateway_resource" "ask_endpoint" {
  rest_api_id = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.findly_rest_api.root_resource_id}"
  path_part        = "ask"
}

resource "aws_api_gateway_method" "ask_endpoint" {
  rest_api_id   = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  resource_id   = "${aws_api_gateway_resource.ask_endpoint.id}"
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "ask_lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  resource_id = "${aws_api_gateway_method.ask_endpoint.resource_id}"
  http_method = "${aws_api_gateway_method.ask_endpoint.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${var.aws_account}:function:ask/invocations"
}

resource "aws_lambda_permission" "apigw_ask" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "ask"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.findly_rest_api.execution_arn}/*/POST/ask"
}

resource "aws_api_gateway_resource" "chat_endpoint" {
  rest_api_id = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  parent_id   = "${aws_api_gateway_rest_api.findly_rest_api.root_resource_id}"
  path_part        = "chat"
}

resource "aws_api_gateway_method" "chat_endpoint" {
  rest_api_id   = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  resource_id   = "${aws_api_gateway_resource.chat_endpoint.id}"
  http_method   = "POST"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "chat_lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  resource_id = "${aws_api_gateway_method.chat_endpoint.resource_id}"
  http_method = "${aws_api_gateway_method.chat_endpoint.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${var.aws_region}:${var.aws_account}:function:chat/invocations"
}

resource "aws_lambda_permission" "apigw_chat" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "chat"
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.findly_rest_api.execution_arn}/*/POST/chat"
}

resource "aws_api_gateway_deployment" "findly_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.index_url_lambda,
    aws_api_gateway_integration.ask_lambda,
    aws_api_gateway_integration.chat_lambda,
  ]

  rest_api_id = "${aws_api_gateway_rest_api.findly_rest_api.id}"
  stage_name  = "v1"
}

output "base_url" {
  value = "${aws_api_gateway_deployment.findly_api_deployment.invoke_url}"
}
