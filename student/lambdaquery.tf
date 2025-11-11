# Crear el ZIP del código Lambda
data "archive_file" "lambdaquery_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function
resource "aws_lambda_function" "consulta" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "lambda-query-${var.student_id}"
  role             = aws_iam_role.lambda.arn
  handler          = "query.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime          = var.lambda_runtime
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory


  layers = [
    local.aws_sdk_pandas_layer_arn   # pandas, numpy, boto3, etc.
  ]

  # Configuración de VPC (Lambda privado)
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  # Variables de entorno
  environment {
    variables = {
      STUDENT_ID          = var.student_id
      S3_BUCKET           = aws_s3_bucket.documents.id
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      OPENSEARCH_INDEX    = "rag-${var.student_id}"
      BEDROCK_MODEL_ID    = var.bedrock_model_id
      # AWS_REGION se proporciona automáticamente por Lambda (no se puede override)
    }
  }

  tags = {
    Name      = "rag-query-${var.student_id}"
    StudentID = var.student_id
  }
}

# CloudWatch Log Group para el Lambda
resource "aws_cloudwatch_log_group" "lambda_query" {
  name              = "/aws/lambda/lambda-query-${var.student_id}"
  retention_in_days = 7

  tags = {
    Name      = "rag-query-${var.student_id}-logs"
    StudentID = var.student_id
  }
}

# Permiso para que S3 invoque el Lambda
resource "aws_lambda_permission" "allow_s3_query" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.consulta.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.documents.arn
}

# Lambda Function URL (opcional - para testing directo)
resource "aws_lambda_function_url" "consulta" {
  function_name      = aws_lambda_function.consulta.function_name
  authorization_type = "AWS_IAM"

  cors {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    max_age       = 86400
  }
}
