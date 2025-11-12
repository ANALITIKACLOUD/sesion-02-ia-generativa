# opensearch.tf

# Solo verificar que el rol existe (sin crearlo)
data "aws_iam_role" "opensearch_service_role" {
  name = "AWSServiceRoleForAmazonOpenSearchService"
}

# Data source para obtener account ID
data "aws_caller_identity" "current" {}

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

  vpc_options {
    subnet_ids         = var.opensearch_instance_count > 1 ? slice(aws_subnet.private[*].id, 0, 2) : [aws_subnet.private[0].id]
    security_group_ids = [aws_security_group.opensearch.id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = false
    internal_user_database_enabled = false
  }

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

  # Solo depende del data source (no del recurso)
  depends_on = [
    data.aws_iam_role.opensearch_service_role
  ]
}