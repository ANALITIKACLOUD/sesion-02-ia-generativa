# AWS Data Wrangler Layer (incluye pandas, numpy, boto3, etc.)
# Este es un layer público mantenido por AWS
# Referencia: https://aws-sdk-pandas.readthedocs.io/en/stable/layers.html
locals {
  # ARN del AWS SDK for pandas (antes AWS Data Wrangler)
  # Para Python 3.11 en us-east-1
  aws_sdk_pandas_layer_arn = "arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python311:23"
}

# Crear el ZIP del Lambda Layer (solo opensearch-py y requests-aws4auth)
data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../layer"
  output_path = "${path.module}/lambda_layer.zip"
  excludes    = ["build.sh", "requirements.txt", "README.md", "Dockerfile", "build-docker.sh"]
}

# Lambda Layer custom para opensearch-py y requests-aws4auth
resource "aws_lambda_layer_version" "opensearch_deps" {
  filename            = data.archive_file.layer_zip.output_path
  layer_name          = "rag-opensearch-${var.alumno_id}"
  compatible_runtimes = [var.lambda_runtime]
  source_code_hash    = data.archive_file.layer_zip.output_base64sha256

  description = "OpenSearch dependencies: opensearch-py, requests-aws4auth"

  lifecycle {
    create_before_destroy = true
  }
}
