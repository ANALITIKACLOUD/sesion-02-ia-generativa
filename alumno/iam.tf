# IAM Role para el Lambda
resource "aws_iam_role" "lambda" {
  name = "rag-lambda-role-${var.alumno_id}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "rag-lambda-role-${var.alumno_id}"
    AlumnoID = var.alumno_id
  }
}

# Policy para logs de CloudWatch
resource "aws_iam_role_policy" "lambda_logging" {
  name = "logging"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/rag-lambda-${var.alumno_id}:*"
      }
    ]
  })
}

# Policy para acceso a VPC (ENI management)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy para acceso a S3
resource "aws_iam_role_policy" "lambda_s3" {
  name = "s3-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.documents.arn,
          "${aws_s3_bucket.documents.arn}/*",
          "arn:aws:s3:::rag-web-ia-gen",
          "arn:aws:s3:::rag-web-ia-gen/*"
        ]
      }
    ]
  })
}

# Policy para acceso a Bedrock
resource "aws_iam_role_policy" "lambda_bedrock" {
  name = "bedrock-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = ["arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_model_id}",
        "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.claude_model_id}"

        ]
      }
    ]
  })
}

# Policy para acceso a OpenSearch
resource "aws_iam_role_policy" "lambda_opensearch" {
  name = "opensearch-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttpGet",
          "es:ESHttpPost",
          "es:ESHttpPut",
          "es:ESHttpDelete"
        ]
        Resource = "${var.opensearch_domain_arn}/*"
      }
    ]
  })
}
