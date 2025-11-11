variable "aws_region" {
  description = "Región de AWS para el taller"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "taller-rag"
}

variable "vpc_cidr" {
  description = "CIDR block para la VPC compartida"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs para subnets privadas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "opensearch_instance_type" {
  description = "Tipo de instancia para OpenSearch"
  type        = string
  default     = "t3.small.search"
}

variable "opensearch_instance_count" {
  description = "Número de instancias OpenSearch (2 para Multi-AZ recomendado)"
  type        = number
  default     = 2
}

variable "opensearch_ebs_volume_size" {
  description = "Tamaño del volumen EBS en GB"
  type        = number
  default     = 20
}

variable "max_students" {
  description = "Número máximo de estudiantes esperados"
  type        = number
  default     = 40
}
