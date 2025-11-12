# Security Group para Lambdas de alumnos
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for alumno Lambda functions"
  vpc_id      = aws_vpc.shared.id

  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

# Security Group para OpenSearch
resource "aws_security_group" "opensearch" {
  name        = "${var.project_name}-opensearch-sg"
  description = "Security group for OpenSearch domain"
  vpc_id      = aws_vpc.shared.id

  tags = {
    Name = "${var.project_name}-opensearch-sg"
  }
}

# Reglas para Lambda SG (como recursos separados para evitar ciclos)

# Lambda -> OpenSearch
resource "aws_security_group_rule" "lambda_to_opensearch" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.opensearch.id
  security_group_id        = aws_security_group.lambda.id
  description              = "HTTPS to OpenSearch"
}

# Lambda -> VPC Endpoints
resource "aws_security_group_rule" "lambda_to_vpc_endpoints" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.vpc_endpoints.id
  security_group_id        = aws_security_group.lambda.id
  description              = "HTTPS to VPC Endpoints"
}

# Lambda -> Internet (para S3 via Gateway Endpoint)
resource "aws_security_group_rule" "lambda_to_internet" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda.id
  description       = "HTTPS outbound (S3 Gateway Endpoint)"
}

# Reglas para OpenSearch SG

# OpenSearch <- Lambda
resource "aws_security_group_rule" "opensearch_from_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lambda.id
  security_group_id        = aws_security_group.opensearch.id
  description              = "HTTPS from Lambda"
}

# OpenSearch -> All (para comunicación interna del cluster)
resource "aws_security_group_rule" "opensearch_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.opensearch.id
  description       = "Allow all outbound"
}
