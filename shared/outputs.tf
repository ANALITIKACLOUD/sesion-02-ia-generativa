# Outputs para que los estudiantes configuren su infraestructura

output "vpc_id" {
  description = "ID de la VPC compartida"
  value       = aws_vpc.shared.id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  value       = aws_subnet.private[*].id
}

output "lambda_security_group_id" {
  description = "ID del Security Group para Lambdas"
  value       = aws_security_group.lambda.id
}

output "opensearch_endpoint" {
  description = "Endpoint del dominio OpenSearch"
  value       = aws_opensearch_domain.shared.endpoint
}

output "opensearch_domain_arn" {
  description = "ARN del dominio OpenSearch"
  value       = aws_opensearch_domain.shared.arn
}

output "opensearch_domain_name" {
  description = "Nombre del dominio OpenSearch"
  value       = aws_opensearch_domain.shared.domain_name
}

output "opensearch_dashboard_endpoint" {
  description = "URL del dashboard de OpenSearch"
  value       = "https://${aws_opensearch_domain.shared.endpoint}/_dashboards"
}

output "terraform_state_bucket" {
  description = "Bucket S3 para estados de Terraform de estudiantes"
  value       = aws_s3_bucket.terraform_state.id
}

output "terraform_locks_table" {
  description = "Tabla DynamoDB para locks de Terraform"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  description = "Región de AWS"
  value       = var.aws_region
}

output "project_name" {
  description = "Nombre del proyecto"
  value       = var.project_name
}

# Instrucciones para estudiantes
output "student_instructions" {
  description = "Instrucciones para configurar el backend de Terraform"
  value = <<-EOT
  
  Para configurar tu infraestructura de estudiante:
  
  1. Ir a la carpeta student/
  2. Copiar terraform.tfvars.example a terraform.tfvars
  3. Editar terraform.tfvars con tu STUDENT_ID único
  4. Ejecutar: terraform init
  5. Ejecutar: terraform apply
  
  Tu backend de Terraform ya está configurado para usar:
  - Bucket: ${aws_s3_bucket.terraform_state.id}
  - DynamoDB: ${aws_dynamodb_table.terraform_locks.name}
  
  EOT
}
