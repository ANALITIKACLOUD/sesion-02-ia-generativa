# API Gateway REST API
resource "aws_api_gateway_rest_api" "query_api" {
  name        = "query-api-${var.student_id}"
  description = "API Gateway para consultas RAG del estudiante ${var.student_id}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name      = "query-api-${var.student_id}"
    StudentID = var.student_id
  }
}

# Recurso /query
resource "aws_api_gateway_resource" "query" {
  rest_api_id = aws_api_gateway_rest_api.query_api.id
  parent_id   = aws_api_gateway_rest_api.query_api.root_resource_id
  path_part   = "query"
}

# Método POST para /query
resource "aws_api_gateway_method" "query_post" {
  rest_api_id   = aws_api_gateway_rest_api.query_api.id
  resource_id   = aws_api_gateway_resource.query.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integración con Lambda
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.query_api.id
  resource_id             = aws_api_gateway_resource.query.id
  http_method             = aws_api_gateway_method.query_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.consulta.invoke_arn
}

# Respuesta del método
resource "aws_api_gateway_method_response" "query_response_200" {
  rest_api_id = aws_api_gateway_rest_api.query_api.id
  resource_id = aws_api_gateway_resource.query.id
  http_method = aws_api_gateway_method.query_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# Deployment del API
resource "aws_api_gateway_deployment" "query_deployment" {
  rest_api_id = aws_api_gateway_rest_api.query_api.id

  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Stage del API
resource "aws_api_gateway_stage" "query_stage" {
  deployment_id = aws_api_gateway_deployment.query_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.query_api.id
  stage_name    = "dev"

  tags = {
    Name      = "query-api-${var.student_id}-dev"
    StudentID = var.student_id
  }
}

# CloudWatch Log Group para API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/query-api-${var.student_id}"
  retention_in_days = 7

  tags = {
    Name      = "query-api-${var.student_id}-logs"
    StudentID = var.student_id
  }
}

# Configuración de logs para el stage
resource "aws_api_gateway_method_settings" "query_settings" {
  rest_api_id = aws_api_gateway_rest_api.query_api.id
  stage_name  = aws_api_gateway_stage.query_stage.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    data_trace_enabled = true
    metrics_enabled    = true
  }
}

# Permiso para que API Gateway invoque la Lambda
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.consulta.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.query_api.execution_arn}/*/*"
}

