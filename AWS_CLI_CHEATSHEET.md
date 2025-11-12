# Comandos AWS CLI Útiles - Taller RAG

## Setup Inicial

### Verificar credenciales AWS
```bash
aws sts get-caller-identity
```

### Configurar región por defecto
```bash
aws configure set default.region us-east-1
```

## VPC y Networking

### Listar VPCs
```bash
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table
```

### Verificar VPC Endpoints
```bash
# Listar todos los VPC endpoints
aws ec2 describe-vpc-endpoints --query 'VpcEndpoints[*].[VpcEndpointId,ServiceName,State]' --output table

# Verificar endpoint específico de Bedrock
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=com.amazonaws.us-east-1.bedrock-runtime" --query 'VpcEndpoints[*].[VpcEndpointId,State]'
```

### Verificar Security Groups
```bash
# Listar security groups del proyecto
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=TallerRAG" --query 'SecurityGroups[*].[GroupId,GroupName]' --output table

# Ver reglas de un security group específico
aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

## Lambda

### Listar funciones Lambda del taller
```bash
aws lambda list-functions --query 'Functions[?starts_with(FunctionName,`rag-lambda`)].FunctionName' --output table
```

### Obtener configuración de una función
```bash
aws lambda get-function-configuration --function-name rag-lambda-alumno01
```

### Invocar Lambda manualmente
```bash
# Index action
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action":"index","bucket":"rag-alumno01","key":"documents/test.txt"}' \
  response.json

# Query action
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action":"query","question":"¿Qué es RAG?","top_k":3}' \
  response.json

cat response.json | jq '.'
```

### Ver logs de Lambda
```bash
# Tail de logs en tiempo real
aws logs tail /aws/lambda/rag-lambda-alumno01 --follow

# Últimos 10 minutos
aws logs tail /aws/lambda/rag-lambda-alumno01 --since 10m

# Buscar errores
aws logs tail /aws/lambda/rag-lambda-alumno01 --filter-pattern "ERROR"
```

### Métricas de Lambda
```bash
# Número de invocaciones (últimas 24h)
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name Invocations \
  --dimensions Name=FunctionName,Value=rag-lambda-alumno01 \
  --start-time $(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Sum
```

## S3

### Listar buckets del taller
```bash
aws s3 ls | grep rag-
```

### Ver contenido de un bucket
```bash
aws s3 ls s3://rag-alumno01/documents/ --recursive
```

### Subir documento
```bash
aws s3 cp sample.txt s3://rag-alumno01/documents/sample.txt
```

### Descargar documento
```bash
aws s3 cp s3://rag-alumno01/documents/sample.txt downloaded.txt
```

### Ver notificaciones configuradas
```bash
aws s3api get-bucket-notification-configuration --bucket rag-alumno01
```

## OpenSearch

### Obtener información del dominio
```bash
aws opensearch describe-domain --domain-name taller-rag
```

### Ver endpoint del dominio
```bash
aws opensearch describe-domain --domain-name taller-rag --query 'DomainStatus.Endpoint' --output text
```

### Ver estado del cluster
```bash
OPENSEARCH_ENDPOINT=$(aws opensearch describe-domain --domain-name taller-rag --query 'DomainStatus.Endpoint' --output text)

curl -XGET "https://$OPENSEARCH_ENDPOINT/_cluster/health?pretty" \
  --user admin:PASSWORD
```

### Listar todos los índices
```bash
curl -XGET "https://$OPENSEARCH_ENDPOINT/_cat/indices?v" \
  --user admin:PASSWORD
```

### Ver índice específico
```bash
curl -XGET "https://$OPENSEARCH_ENDPOINT/rag-alumno01?pretty" \
  --user admin:PASSWORD
```

### Buscar en un índice
```bash
curl -XGET "https://$OPENSEARCH_ENDPOINT/rag-alumno01/_search?pretty" \
  --user admin:PASSWORD \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match_all": {}
    }
  }'
```

### Eliminar un índice (con cuidado!)
```bash
curl -XDELETE "https://$OPENSEARCH_ENDPOINT/rag-alumno01" \
  --user admin:PASSWORD
```

## Bedrock

### Listar modelos disponibles
```bash
aws bedrock list-foundation-models --query 'modelSummaries[*].[modelId,modelName]' --output table
```

### Ver detalles de un modelo específico
```bash
aws bedrock get-foundation-model --model-identifier amazon.titan-embed-text-v1
```

### Probar invocación de Bedrock (embeddings)
```bash
aws bedrock-runtime invoke-model \
  --model-id amazon.titan-embed-text-v1 \
  --body '{"inputText":"Hello world"}' \
  output.json

cat output.json | jq '.embedding | length'
```

## IAM

### Ver roles del taller
```bash
aws iam list-roles --query 'Roles[?contains(RoleName,`rag-lambda`)].RoleName' --output table
```

### Ver policies de un role
```bash
aws iam list-role-policies --role-name rag-lambda-role-alumno01
```

### Ver detalles de una policy inline
```bash
aws iam get-role-policy \
  --role-name rag-lambda-role-alumno01 \
  --policy-name bedrock-access
```

## CloudWatch

### Ver log groups del taller
```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/rag-lambda
```

### Buscar en logs
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/rag-lambda-alumno01 \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s)000
```

### Crear alarma para errores de Lambda
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name rag-lambda-alumno01-errors \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=rag-lambda-alumno01 \
  --evaluation-periods 1
```

## Terraform State (S3 + DynamoDB)

### Ver estados de Terraform en S3
```bash
aws s3 ls s3://taller-rag-terraform-state/alumnos/ --recursive
```

### Ver locks activos en DynamoDB
```bash
aws dynamodb scan --table-name taller-rag-terraform-locks
```

### Eliminar un lock manualmente (emergencia)
```bash
aws dynamodb delete-item \
  --table-name taller-rag-terraform-locks \
  --key '{"LockID": {"S": "taller-rag-terraform-state/alumnos/alumno01/terraform.tfstate"}}'
```

## Service Quotas

### Ver límites actuales
```bash
# VPC Endpoints
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-45FE3B85

# Lambda concurrent executions
aws service-quotas get-service-quota \
  --service-code lambda \
  --quota-code L-B99A9384

# OpenSearch instances
aws service-quotas get-service-quota \
  --service-code es \
  --quota-code L-6408ABDE
```

### Solicitar aumento de cuota
```bash
aws service-quotas request-service-quota-increase \
  --service-code lambda \
  --quota-code L-B99A9384 \
  --desired-value 200
```

## Costos

### Ver costos del día actual
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d yesterday +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=SERVICE
```

### Ver costos por tag
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-10 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=TAG,Key=Project \
  --filter file://filter.json

# filter.json:
# {
#   "Tags": {
#     "Key": "Project",
#     "Values": ["TallerRAG"]
#   }
# }
```

## Cleanup Rápido

### Eliminar todos los Lambdas del taller
```bash
for func in $(aws lambda list-functions --query 'Functions[?starts_with(FunctionName,`rag-lambda`)].FunctionName' --output text); do
  echo "Eliminando $func..."
  aws lambda delete-function --function-name $func
done
```

### Eliminar todos los buckets S3 del taller
```bash
for bucket in $(aws s3 ls | grep rag- | awk '{print $3}'); do
  echo "Vaciando $bucket..."
  aws s3 rm s3://$bucket --recursive
  echo "Eliminando $bucket..."
  aws s3 rb s3://$bucket
done
```

### Verificar que no queden recursos
```bash
# Lambdas
aws lambda list-functions --query 'Functions[?starts_with(FunctionName,`rag-`)].FunctionName'

# S3
aws s3 ls | grep rag-

# IAM Roles
aws iam list-roles --query 'Roles[?contains(RoleName,`rag-`)].RoleName'

# CloudWatch Log Groups
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/rag-
```

## SSM Parameter Store

### Ver parámetros del taller
```bash
aws ssm describe-parameters --filters "Key=Name,Values=/taller-rag/"
```

### Obtener password de OpenSearch
```bash
aws ssm get-parameter \
  --name /taller-rag/opensearch/master-password \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

## Troubleshooting

### Lambda no puede conectarse a Bedrock
```bash
# 1. Verificar VPC endpoint existe y está disponible
aws ec2 describe-vpc-endpoints \
  --filters "Name=service-name,Values=com.amazonaws.us-east-1.bedrock-runtime" \
  --query 'VpcEndpoints[*].[VpcEndpointId,State]'

# 2. Verificar security groups permiten tráfico
aws lambda get-function-configuration \
  --function-name rag-lambda-alumno01 \
  --query 'VpcConfig.SecurityGroupIds'

# 3. Verificar IAM permissions
aws iam get-role-policy \
  --role-name rag-lambda-role-alumno01 \
  --policy-name bedrock-access
```

### Lambda timeout
```bash
# Ver configuración de timeout
aws lambda get-function-configuration \
  --function-name rag-lambda-alumno01 \
  --query '[Timeout,MemorySize]'

# Aumentar timeout
aws lambda update-function-configuration \
  --function-name rag-lambda-alumno01 \
  --timeout 120
```

## Scripts Combinados

### Monitoreo completo de un alumno
```bash
#!/bin/bash
ALUMNO_ID=$1

echo "=== Lambda Status ==="
aws lambda get-function --function-name rag-lambda-$ALUMNO_ID --query 'Configuration.[State,LastUpdateStatus]'

echo "=== Recent Logs ==="
aws logs tail /aws/lambda/rag-lambda-$ALUMNO_ID --since 5m

echo "=== S3 Files ==="
aws s3 ls s3://rag-$ALUMNO_ID/documents/

echo "=== OpenSearch Index ==="
OPENSEARCH_ENDPOINT=$(aws opensearch describe-domain --domain-name taller-rag --query 'DomainStatus.Endpoint' --output text)
curl -s -XGET "https://$OPENSEARCH_ENDPOINT/_cat/indices/rag-$ALUMNO_ID?v" --user admin:PASSWORD
```

### Health check completo
```bash
#!/bin/bash
echo "Checking infrastructure health..."

# VPC Endpoints
echo "VPC Endpoints:"
aws ec2 describe-vpc-endpoints --filters "Name=tag:Project,Values=TallerRAG" --query 'VpcEndpoints[*].[ServiceName,State]' --output table

# OpenSearch
echo "OpenSearch:"
aws opensearch describe-domain --domain-name taller-rag --query 'DomainStatus.[DomainName,Processing,UpgradeProcessing]'

# Lambda functions
echo "Lambda Functions:"
aws lambda list-functions --query 'Functions[?starts_with(FunctionName,`rag-lambda`)].{Name:FunctionName,State:State}' --output table
```
