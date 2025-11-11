# S3 bucket para almacenar documentos del estudiante
resource "aws_s3_bucket" "documents" {
  bucket = "rag-${var.student_id}"

  tags = {
    Name      = "rag-${var.student_id}"
    StudentID = var.student_id
  }
}

# Versionado del bucket
# resource "aws_s3_bucket_versioning" "documents" {
#   bucket = aws_s3_bucket.documents.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# Encriptación del bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquear acceso público
resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle rule para limpiar objetos viejos (opcional)
resource "aws_s3_bucket_lifecycle_configuration" "documents" {
  bucket = aws_s3_bucket.documents.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

# Notificación S3 -> Lambda (para procesamiento automático)
resource "aws_s3_bucket_notification" "documents" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.rag.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    # Sin filter_suffix = procesa cualquier archivo (.txt, .pdf, etc.)
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
