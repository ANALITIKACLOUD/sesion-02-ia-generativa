# Arquitectura RAG con Dos Lambdas

## 📋 Resumen

Este proyecto implementa una arquitectura RAG (Retrieval-Augmented Generation) con dos Lambdas especializados:

1. **Lambda Indexer** (`indexer.py`): Procesa documentos y genera embeddings
2. **Lambda Query** (`query.py`): Realiza búsquedas semánticas

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    ARQUITECTURA RAG                          │
└─────────────────────────────────────────────────────────────┘

1. INDEXING PIPELINE
   ┌──────┐         ┌──────────────┐        ┌───────────┐
   │  S3  │────────>│ Lambda       │───────>│ OpenSearch│
   │Bucket│ trigger │ Indexer      │ KNN    │  Index    │
   └──────┘         │              │        └───────────┘
                    │ - Lee S3     │              ↑
                    │ - Bedrock    │              │
                    │ - Embeddings │──────────────┘
                    └──────────────┘

2. QUERY PIPELINE
   ┌──────┐         ┌──────────────┐        ┌───────────┐
   │ User │────────>│ Lambda       │───────>│ OpenSearch│
   │Query │ invoke  │ Query        │ KNN    │  Search   │
   └──────┘         │              │        └───────────┘
                    │ - Embedding  │              │
                    │ - KNN Search │<─────────────┘
                    │ - Resultados │
                    └──────────────┘
```

---

## 📦 Componentes

### 1. Lambda Indexer

**Archivo:** `lambda/indexer.py`

**Propósito:** Procesar documentos de S3 e indexarlos en OpenSearch

**Trigger:** S3 ObjectCreated events

**Flujo:**
```
1. S3 event trigger
2. Leer documento desde S3
3. Generar embedding con Bedrock Titan
4. Crear/actualizar índice OpenSearch
5. Indexar documento con embedding
```

**Variables de entorno:**
- `ALUMNO_ID`: ID del alumno
- `S3_BUCKET`: Bucket de documentos
- `OPENSEARCH_ENDPOINT`: Endpoint de OpenSearch
- `OPENSEARCH_INDEX`: Nombre del índice
- `BEDROCK_MODEL_ID`: Modelo de embeddings

**Ejemplo de uso:**
```bash
# El indexing es automático cuando subes un archivo
aws s3 cp document.txt s3://your-bucket/documents/document.txt

# Verificar logs
aws logs tail /aws/lambda/rag-indexer-{alumno_id} --follow
```

---

### 2. Lambda Query

**Archivo:** `lambda/query.py`

**Propósito:** Realizar búsquedas semánticas en documentos indexados

**Trigger:** Manual (invoke o Function URL)

**Flujo:**
```
1. Recibir query del usuario
2. Generar embedding del query
3. Búsqueda KNN en OpenSearch
4. Retornar documentos más similares con scores
```

**Variables de entorno:**
- `ALUMNO_ID`: ID del alumno
- `OPENSEARCH_ENDPOINT`: Endpoint de OpenSearch
- `OPENSEARCH_INDEX`: Nombre del índice
- `BEDROCK_MODEL_ID`: Modelo de embeddings

**Ejemplo de uso:**
```bash
# Búsqueda básica
aws lambda invoke \
  --function-name rag-query-{alumno_id} \
  --payload '{"query": "What is OpenSearch?"}' \
  response.json

# Ver respuesta
cat response.json | jq '.'

# Búsqueda con más resultados
aws lambda invoke \
  --function-name rag-query-{alumno_id} \
  --payload '{"query": "machine learning", "k": 10}' \
  response.json
```

---

## 🔧 Configuración Terraform

### Actualización de `lambda.tf`

El archivo fue actualizado para incluir 3 Lambdas:

```hcl
# Lambda Indexer - Procesa documentos
resource "aws_lambda_function" "indexer" {
  function_name = "rag-indexer-${var.alumno_id}"
  handler       = "indexer.handler"
  # ... configuración VPC, IAM, etc
}

# Lambda Query - Búsquedas
resource "aws_lambda_function" "query" {
  function_name = "rag-query-${var.alumno_id}"
  handler       = "query.handler"
  # ... configuración VPC, IAM, etc
}

# Lambda Test - Conectividad
resource "aws_lambda_function" "test" {
  function_name = "rag-test-${var.alumno_id}"
  handler       = "index.handler"
  # ... configuración VPC, IAM, etc
}
```

---

## 🚀 Deployment

### 1. Desplegar infraestructura

```bash
cd alumno/

# Inicializar Terraform
terraform init

# Aplicar cambios
terraform apply

# Ver outputs
terraform output
```

### 2. Verificar deployment

```bash
# Verificar Lambdas creados
aws lambda list-functions | grep rag-

# Debe mostrar:
# - rag-indexer-{alumno_id}
# - rag-query-{alumno_id}
# - rag-test-{alumno_id}
```

---

## 🧪 Testing

### Test 1: Conectividad

```bash
# Invocar Lambda de test
aws lambda invoke \
  --function-name rag-test-{alumno_id} \
  response.json

# Ver resultado
cat response.json | jq '.body | fromjson'
```

### Test 2: Indexar documento

```bash
# Crear documento de prueba
cat > test-document.txt << EOF
OpenSearch is a community-driven, open source search and analytics suite.
It provides powerful full-text search capabilities and supports vector search
for semantic similarity using KNN algorithms.
EOF

# Subir a S3 (trigger automático del Indexer)
aws s3 cp test-document.txt \
  s3://rag-{alumno_id}/documents/test-document.txt

# Ver logs del indexer
aws logs tail /aws/lambda/rag-indexer-{alumno_id} --follow
```

### Test 3: Realizar búsqueda

```bash
# Búsqueda simple
aws lambda invoke \
  --function-name rag-query-{alumno_id} \
  --payload '{"query": "What is OpenSearch?"}' \
  response.json

# Ver resultados
cat response.json | jq '.body | fromjson'

# Búsqueda con más resultados
aws lambda invoke \
  --function-name rag-query-{alumno_id} \
  --payload '{"query": "vector search", "k": 5}' \
  response.json
```

### Test 4: Verificar OpenSearch

```bash
# Count de documentos
aws lambda invoke \
  --function-name rag-query-{alumno_id} \
  --payload '{"query": "test"}' \
  response.json

# Ver estructura del resultado
cat response.json | jq '.body | fromjson.results[0]'
```

---

## 📊 Formato de Respuesta

### Query Response

```json
{
  "statusCode": 200,
  "body": {
    "query": "What is OpenSearch?",
    "results_count": 3,
    "results": [
      {
        "document_id": "documents_test-document_txt",
        "score": 0.856,
        "text": "OpenSearch is a community-driven...",
        "metadata": {
          "bucket": "rag-12345",
          "key": "documents/test-document.txt",
          "alumno_id": "12345",
          "size": 189
        },
        "indexed_at": "2025-01-10T15:30:00Z"
      }
    ]
  }
}
```

---

## 🔍 API del Lambda Query

### Request Format

```json
{
  "query": "your search text",
  "k": 5,                    // opcional: número de resultados (default: 5)
  "include_metadata": true   // opcional: incluir metadata (default: true)
}
```

### Response Format

```json
{
  "query": "search text",
  "results_count": 3,
  "results": [
    {
      "document_id": "doc_id",
      "score": 0.92,
      "text": "document content...",
      "metadata": {...},
      "indexed_at": "2025-01-10T15:30:00Z"
    }
  ]
}
```

---

## 🐛 Troubleshooting

### Problema: Lambda Query no encuentra documentos

```bash
# 1. Verificar que el índice existe
aws lambda invoke \
  --function-name rag-test-{alumno_id} \
  response.json

# 2. Ver si hay documentos indexados
cat response.json | jq '.body | fromjson.tests.opensearch_indices'

# 3. Verificar logs del indexer
aws logs tail /aws/lambda/rag-indexer-{alumno_id} --since 1h
```

### Problema: Error de permisos

```bash
# Verificar IAM role del Lambda
aws lambda get-function \
  --function-name rag-query-{alumno_id} \
  --query 'Configuration.Role'

# Verificar políticas adjuntas
aws iam list-attached-role-policies \
  --role-name rag-lambda-role-{alumno_id}
```

### Problema: Timeout del Lambda

```bash
# Aumentar timeout en variables.tf
variable "lambda_timeout" {
  default = 60  # aumentar a 60 segundos
}

# Aplicar cambios
terraform apply
```

---

## 📚 Referencias

- [OpenSearch KNN](https://opensearch.org/docs/latest/search-plugins/knn/index/)
- [AWS Bedrock Embeddings](https://docs.aws.amazon.com/bedrock/latest/userguide/embeddings.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

---

## ✅ Checklist de Deployment

- [ ] Terraform apply exitoso
- [ ] 3 Lambdas creados (indexer, query, test)
- [ ] Test Lambda pasa todos los tests
- [ ] Documento de prueba indexado
- [ ] Query Lambda retorna resultados
- [ ] Logs de CloudWatch funcionando

---

## 🎯 Próximos Pasos

1. **Integrar con API Gateway** para exponer Query Lambda via HTTP
2. **Agregar autenticación** (Cognito o IAM)
3. **Implementar cache** para queries frecuentes
4. **Agregar monitoring** con CloudWatch Metrics
5. **Optimizar embeddings** ajustando modelo de Bedrock
