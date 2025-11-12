# Lambda Function - RAG Pipeline

## Descripción

Esta función Lambda implementa un pipeline RAG (Retrieval Augmented Generation) que:
1. Recibe documentos desde S3
2. Genera embeddings usando Bedrock (Titan Embeddings)
3. Indexa documentos en OpenSearch con búsqueda vectorial
4. Permite queries semánticas

## Funcionalidades

### 1. Indexación Automática (S3 Event)
Cuando subes un documento a S3, se dispara automáticamente:
```bash
aws s3 cp documento.txt s3://rag-alumno01/documents/
```

### 2. Indexación Manual
```bash
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action": "index", "bucket": "rag-alumno01", "key": "documents/test.txt"}' \
  response.json
```

### 3. Query Semántica
```bash
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action": "query", "question": "¿Qué es RAG?"}' \
  response.json
```

### 4. Crear Índice Manualmente
```bash
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action": "create_index"}' \
  response.json
```

## Variables de Entorno Requeridas

- `ALUMNO_ID`: ID del alumno (ej: alumno01)
- `S3_BUCKET`: Bucket S3 para documentos
- `OPENSEARCH_ENDPOINT`: Endpoint de OpenSearch
- `OPENSEARCH_INDEX`: Nombre del índice (ej: rag-alumno01)
- `BEDROCK_MODEL_ID`: Modelo de Bedrock (amazon.titan-embed-text-v1)
- `AWS_REGION`: Región de AWS

## Estructura de Documento en OpenSearch

```json
{
  "text": "Contenido del documento...",
  "embedding": [0.123, -0.456, ...],  // Vector de 1536 dimensiones
  "metadata": {
    "bucket": "rag-alumno01",
    "key": "documents/test.txt",
    "alumno_id": "alumno01"
  },
  "timestamp": "2025-11-10T15:30:00Z"
}
```

## Testing Local

Para probar localmente (requiere credenciales AWS):

```python
# test_lambda.py
from index import handler

# Test query
event = {
    "action": "query",
    "question": "¿Qué es machine learning?"
}

response = handler(event, None)
print(response)
```

## Dependencias

Las dependencias ahora están separadas en un **Lambda Layer** para reducir el tamaño del código.

### Lambda Layer (ver ../layer/)
- pandas: Procesamiento de datos
- numpy: Operaciones numéricas
- boto3: Cliente AWS
- opensearch-py: Cliente OpenSearch
- requests-aws4auth: Autenticación AWS para OpenSearch

### Código Lambda (este directorio)
- `indexer.py`: Handler principal para indexación S3
- `query.py`: Handler para queries semánticas
- `index.py`: Lógica de indexación
- `shared.py`: Utilidades compartidas

### Build Process
1. Construir layer: `cd ../layer && ./build.sh`
2. Limpiar lambda: `cd ../lambda && ./clean.sh`
3. Desplegar: `cd ../student && terraform apply`

## Troubleshooting

### Lambda timeout
- Aumentar timeout a 60s (configurable en terraform)
- Verificar que VPC endpoints estén activos

### No puede conectarse a OpenSearch
- Verificar security group permite tráfico desde Lambda SG
- Verificar que Lambda está en las subnets correctas

### Bedrock access denied
- Verificar IAM role tiene permiso `bedrock:InvokeModel`
- Verificar que el modelo está habilitado en la región

### OpenSearch index not found
- El índice se crea automáticamente al indexar el primer documento
- O crear manualmente con `{"action": "create_index"}`
