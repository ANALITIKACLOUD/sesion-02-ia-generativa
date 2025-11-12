# Outputs para el alumno

output "alumno_id" {
  description = "ID del alumno"
  value       = var.alumno_id
}

output "s3_bucket_name" {
  description = "Nombre del bucket S3 para documentos"
  value       = aws_s3_bucket.documents.id
}

output "lambda_function_name" {
  description = "Nombre de la función Lambda"
  value       = aws_lambda_function.rag.function_name
}

output "lambda_function_arn" {
  description = "ARN de la función Lambda"
  value       = aws_lambda_function.rag.arn
}

output "lambda_function_url" {
  description = "URL de la función Lambda"
  value       = aws_lambda_function_url.rag.function_url
}

output "opensearch_index" {
  description = "Nombre del índice de OpenSearch asignado"
  value       = "rag-${var.alumno_id}"
}
### funcion query
output "lambda_query_function_name" {
  description = "Nombre de la función Lambda de consulta"
  value       = aws_lambda_function.consulta.function_name
}

output "lambda_query_function_arn" {
  description = "ARN de la función Lambda de consulta"
  value       = aws_lambda_function.consulta.arn
}

output "lambda_query_function_url" {
  description = "URL de la función Lambda de consulta"
  value       = aws_lambda_function_url.consulta.function_url
}

output "api_gateway_url" {
  description = "URL del API Gateway para consultas"
  value       = "${aws_api_gateway_stage.query_stage.invoke_url}/query"
}

output "api_gateway_id" {
  description = "ID del API Gateway"
  value       = aws_api_gateway_rest_api.query_api.id
}
