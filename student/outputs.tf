# Outputs para el estudiante

output "student_id" {
  description = "ID del estudiante"
  value       = var.student_id
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
  value       = "rag-${var.student_id}"
}

output "test_commands" {
  description = "Comandos para probar tu infraestructura"
  value = <<-EOT
  
  ========================================
  COMANDOS DE PRUEBA
  ========================================
  
  1. Subir un documento de prueba:
  
     aws s3 cp sample.txt s3://${aws_s3_bucket.documents.id}/documents/sample.txt
  
  2. Invocar Lambda para indexar (trigger automático por S3):
  
     aws lambda invoke \
       --function-name ${aws_lambda_function.rag.function_name} \
       --payload '{"action": "index", "bucket": "${aws_s3_bucket.documents.id}", "key": "documents/sample.txt"}' \
       response.json
  
  3. Hacer una consulta RAG:
  
     aws lambda invoke \
       --function-name ${aws_lambda_function.rag.function_name} \
       --payload '{"action": "query", "question": "¿De qué trata el documento?"}' \
       response.json
  
  4. Ver logs:
  
     aws logs tail /aws/lambda/${aws_lambda_function.rag.function_name} --follow
  
  5. Verificar índice en OpenSearch:
     
     curl -XGET "https://${var.opensearch_endpoint}/rag-${var.student_id}/_search?pretty" \
       --user admin:PASSWORD
  
  ========================================
  EOT
}
