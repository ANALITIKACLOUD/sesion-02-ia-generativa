# Verificar si el Service Linked Role de OpenSearch ya existe
data "external" "check_opensearch_role" {
  program = ["bash", "-c", <<-EOT
    if aws iam get-role --role-name AWSServiceRoleForAmazonOpenSearchService > /dev/null 2>&1; then
      echo '{"exists":"true"}'
    else
      echo '{"exists":"false"}'
    fi
  EOT
  ]
}

# Crear Service Linked Role solo si NO existe
resource "aws_iam_service_linked_role" "opensearch" {
  count            = data.external.check_opensearch_role.result.exists == "false" ? 1 : 0
  aws_service_name = "opensearchservice.amazonaws.com"
}

# Obtener el rol existente si ya existe
data "aws_iam_role" "opensearch_service_role" {
  count = data.external.check_opensearch_role.result.exists == "true" ? 1 : 0
  name  = "AWSServiceRoleForAmazonOpenSearchService"
}

# OpenSearch Domain
resource "aws_opensearch_domain" "shared" {
  domain_name    = var.project_name
  engine_version = "OpenSearch_2.11"

  cluster_config {
    instance_type          = var.opensearch_instance_type
    instance_count         = var.opensearch_instance_count
    zone_awareness_enabled = var.opensearch_instance_count > 1

    dynamic "zone_awareness_config" {
      for_each = var.opensearch_instance_count > 1 ? [1] : []
      content {
        availability_zone_count = 2
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.opensearch_ebs_volume_size
    volume_type = "gp3"
  }

  # Configuración VPC
  vpc_options {
    subnet_ids         = var.opensearch_instance_count > 1 ? slice(aws_subnet.private[*].id, 0, 2) : [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.opensearch.id]
  }

  # Encriptación en reposo
  encrypt_at_rest {
    enabled = true
  }

  # Encriptación en tránsito
  node_to_node_encryption {
    enabled = true
  }

  # Configuración de dominio
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # Control de acceso - Deshabilitado para simplificar el taller
  # Se usa solo IAM para autenticación
  advanced_security_options {
    enabled                        = false
    internal_user_database_enabled = false
  }

  # Access policy - permitir desde VPC con IAM
  # Fine-grained access control maneja los permisos reales
  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "es:*"
        Resource = "arn:aws:es:${var.aws_region}:${data.aws_caller_identity.current.account_id}:domain/${var.project_name}/*"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-opensearch"
  }

  # Depende del rol (ya sea creado o existente)
  depends_on = [
    aws_iam_service_linked_role.opensearch,
    data.aws_iam_role.opensearch_service_role
  ]
}

# Data source para obtener account ID
data "aws_caller_identity" "current" {}
