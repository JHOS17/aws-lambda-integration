# Variables propias del API Gateway
variable "cors_allowed_origins" {
  description = "Orígenes permitidos por CORS para cada entorno"
  type        = list(string)
}

variable "api_throttling_rate_limit" {
  description = "Solicitudes por segundo permitidas (limite sostenido)"
  type        = number
  default     = 25
}

variable "api_throttling_burst_limit" {
  description = "Rafaga maxima de solicitudes"
  type        = number
  default     = 50
}

variable "api_log_retention_days" {
  description = "Dias de retencion de los access logs en CloudWatch"
  type        = number
  default     = 14
}

variable "custom_domain_name" {
  description = "Dominio personalizado del API (opcional). Si es null se usa el endpoint execute-api."
  type        = string
  default     = null
}

variable "custom_domain_certificate_arn" {
  description = "ARN del certificado ACM (misma region) para el dominio personalizado"
  type        = string
  default     = null
}

# HTTP API
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name}-http-api"
  protocol_type = "HTTP"
  description   = "API para subir imagenes al procesador (${var.environment})"

  cors_configuration {
    allow_origins = var.cors_allowed_origins
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }

  tags = local.common_tags

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || !contains(var.cors_allowed_origins, "*")
      error_message = "En prod debes configurar origenes CORS especificos; no se permite '*'."
    }
  }
}

# Integracion Lambda proxy con payload format 2.0
resource "aws_apigatewayv2_integration" "upload" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.upload_lambda.invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 30000
}

# Ruta POST /upload
resource "aws_apigatewayv2_route" "upload" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

# Access logs
resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/aws/apigateway/${local.name}-http-api"
  retention_in_days = var.api_log_retention_days

  tags = local.common_tags
}

# Stage $default con despliegue automatico, logs y throttling
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.api_throttling_rate_limit
    throttling_burst_limit = var.api_throttling_burst_limit
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn

    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      errorMessage     = "$context.error.message"
    })
  }

  tags = local.common_tags

  depends_on = [aws_apigatewayv2_route.upload]
}

# TLS 1.2: solo aplica a dominios personalizados. El endpoint execute-api
# por defecto ya exige TLS 1.2 como minimo y no es configurable.
resource "aws_apigatewayv2_domain_name" "custom" {
  count       = var.custom_domain_name != null ? 1 : 0
  domain_name = var.custom_domain_name

  domain_name_configuration {
    certificate_arn = var.custom_domain_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_api_mapping" "custom" {
  count       = var.custom_domain_name != null ? 1 : 0
  api_id      = aws_apigatewayv2_api.http.id
  domain_name = aws_apigatewayv2_domain_name.custom[0].id
  stage       = aws_apigatewayv2_stage.default.id
}

# Permiso: API Gateway puede invocar SOLO la Upload Lambda, SOLO por POST /upload
resource "aws_lambda_permission" "apigw_invoke_upload" {
  statement_id  = "AllowAPIGatewayInvokeUpload"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/POST/upload"
}

# Outputs
output "api_endpoint" {
  description = "URL base del HTTP API (usar <url>/upload)"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "api_id" {
  description = "ID del HTTP API"
  value       = aws_apigatewayv2_api.http.id
}

output "api_custom_domain_target" {
  description = "Nombre regional al que apuntar el CNAME/alias del dominio personalizado (si se usa)"
  value       = try(aws_apigatewayv2_domain_name.custom[0].domain_name_configuration[0].target_domain_name, null)
}