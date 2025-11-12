variable "alumno_id" {
  description = "ID único del alumno en formato nombre-apellido (ej: artemio-perlacios)"
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+$", var.alumno_id))
    error_message = "El alumno_id debe tener el formato 'nombre-apellido' en minúsculas (ej: artemio-perlacios)"
  }
}

variable "aws_region" {
  description = "Región de AWS"
  type        = string
  default     = "us-east-1"
}

# Variables de la infraestructura compartida (vienen de outputs)
variable "vpc_id" {
  description = "ID de la VPC compartida"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "ID del Security Group para Lambda"
  type        = string
}

variable "opensearch_endpoint" {
  description = "Endpoint del dominio OpenSearch compartido"
  type        = string
}

variable "opensearch_domain_arn" {
  description = "ARN del dominio OpenSearch compartido"
  type        = string
}

variable "lambda_runtime" {
  description = "Runtime de Lambda"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Timeout del Lambda en segundos"
  type        = number
  default     = 60
}

variable "lambda_memory" {
  description = "Memoria del Lambda en MB"
  type        = number
  default     = 512
}

variable "bedrock_model_id" {
  description = "ID del modelo de Bedrock para embeddings"
  type        = string
  default     = "amazon.titan-embed-text-v1"
}
variable "claude_model_id" {
  description = "ID del modelo de claude"
  type        = string
  default     = "anthropic.claude-3-sonnet-20240229-v1:0"
}
