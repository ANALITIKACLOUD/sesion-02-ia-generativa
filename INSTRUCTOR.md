# Guía del Instructor - Taller RAG

## Pre-taller (1-2 días antes)

### 1. Verificar Service Quotas

```bash
# Verificar límites críticos
make check-quotas

# Solicitar aumentos si es necesario:
# - VPC Endpoints: Mínimo 5
# - Lambda concurrent executions: Mínimo 100
# - OpenSearch instances: Mínimo 1
```

### 2. Habilitar Bedrock

1. Ir a AWS Console → Bedrock → Model access
2. Habilitar: `amazon.titan-embed-text-v1`
3. Verificar que esté disponible en la región seleccionada

### 3. Desplegar Infraestructura Compartida

```bash
# 1. Configurar región en shared/variables.tf (si no es us-east-1)

# 2. Desplegar
make setup-shared
make deploy-shared

# Esto tomará ~15-20 minutos (OpenSearch es lento)

# 3. Exportar outputs
make outputs

# Esto crea shared-outputs.json que necesitarán los alumnos
```

### 4. Preparar Repositorio

```bash
# Subir a GitHub/GitLab
git init
git add .
git commit -m "Taller RAG - Configuración inicial"
git remote add origin <repo-url>
git push -u origin main

# Compartir URL del repositorio con alumnos
```

### 5. Preparar Cloud9 Environments (Opcional)

Si usas Cloud9 para los alumnos:

```bash
# Crear 35 ambientes Cloud9 (puede automatizarse)
for i in {01..35}; do
    aws cloud9 create-environment-ec2 \
        --name "taller-rag-alumno$i" \
        --instance-type t3.small \
        --subnet-id <subnet-id>
done
```

## Durante el Taller

### Timeline Sugerido (4 horas)

#### Hora 1: Introducción y Teoría (60 min)
- **00:00-00:15**: Bienvenida y objetivos
- **00:15-00:30**: ¿Qué es RAG? Conceptos básicos
- **00:30-00:45**: Arquitectura del taller (diagrama)
- **00:45-01:00**: Demo del instructor

#### Hora 2: Setup y Despliegue (60 min)
- **01:00-01:10**: Git clone del repositorio
- **01:10-01:20**: Explicar estructura de carpetas
- **01:20-01:40**: Cada alumno ejecuta setup y deploy
  ```bash
  git clone <repo-url>
  cd a
  make setup-student  # Configura su ALUMNO_ID
  make deploy-student # Despliega su infra
  ```
- **01:40-02:00**: Troubleshooting y ayuda

#### Hora 3: Testing y Experimentación (60 min)
- **02:00-02:15**: Explicar cómo probar el sistema
- **02:15-02:30**: Cada alumno sube un documento y hace queries
  ```bash
  make test ALUMNO_ID=alumno01
  ```
- **02:30-02:45**: Ver logs y dashboard de OpenSearch
- **02:45-03:00**: Experimentos libres

#### Hora 4: Conceptos Avanzados y Cleanup (60 min)
- **03:00-03:20**: Discusión sobre mejoras posibles
- **03:20-03:40**: Q&A y troubleshooting final
- **03:40-03:50**: Cleanup de infraestructura
  ```bash
  make destroy-student
  ```
- **03:50-04:00**: Conclusiones y recursos adicionales

## Comandos Útiles Durante el Taller

### Monitorear Recursos

```bash
# Ver todos los alumnos activos
make list-alumnos

# Ver logs de un alumno específico
make logs ALUMNO_ID=alumno01

# Verificar estado de OpenSearch
aws opensearch describe-domain --domain-name taller-rag
```

### Troubleshooting Común

#### 1. Lambda no puede conectarse a Bedrock
```bash
# Verificar VPC endpoint
aws ec2 describe-vpc-endpoints --filters "Name=service-name,Values=com.amazonaws.us-east-1.bedrock-runtime"

# Verificar security group del Lambda
aws lambda get-function-configuration --function-name rag-lambda-alumno01 | jq '.VpcConfig'
```

#### 2. Lambda no puede escribir en OpenSearch
```bash
# Verificar IAM role del Lambda
aws iam get-role-policy --role-name rag-lambda-role-alumno01 --policy-name opensearch-access

# Verificar security group de OpenSearch
aws opensearch describe-domain --domain-name taller-rag | jq '.DomainStatus.VPCOptions'
```

#### 3. Terraform state locks
```bash
# Listar locks activos
aws dynamodb scan --table-name taller-rag-terraform-locks

# Liberar un lock (con cuidado!)
cd student
terraform force-unlock <lock-id>
```

#### 4. OpenSearch dashboard no carga
```bash
# Obtener password
aws ssm get-parameter --name /taller-rag/opensearch/master-password --with-decryption

# URL del dashboard
cd shared
terraform output opensearch_dashboard_endpoint
```

### Demostración Live

Script para demo del instructor:

```bash
# 1. Mostrar arquitectura
cat README.md

# 2. Desplegar un alumno de ejemplo
export ALUMNO_ID=demo
cd student
cp terraform.tfvars.example terraform.tfvars
# Editar con ALUMNO_ID=demo
terraform apply

# 3. Subir documento
aws s3 cp sample-document.txt s3://rag-demo/documents/

# 4. Query
aws lambda invoke \
  --function-name rag-lambda-demo \
  --payload '{"action":"query","question":"¿Qué es RAG?"}' \
  response.json

cat response.json | jq '.body | fromjson'

# 5. Ver logs
aws logs tail /aws/lambda/rag-lambda-demo --follow
```

## Post-Taller

### 1. Cleanup de Alumnos

```bash
# Si algunos alumnos no hicieron destroy
bash scripts/cleanup-all.sh
```

### 2. Destruir Infraestructura Compartida

```bash
make destroy-shared
```

### 3. Verificar Costos

```bash
# Ver costos del día
aws ce get-cost-and-usage \
  --time-period Start=$(date -d yesterday +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost
```

### 4. Feedback

- Encuesta post-taller
- Documentar issues encontrados
- Actualizar README con lecciones aprendidas

## Costos Estimados

Para un taller de 4 horas con 35 alumnos:

| Recurso | Costo |
|---------|-------|
| OpenSearch t3.small (4h) | ~$0.58 |
| VPC Endpoint Bedrock (4h) | ~$0.12 |
| Lambda (35 × 100 invocaciones) | ~$0.00 |
| S3 (35 buckets, pocos MB) | ~$0.01 |
| **Total** | **~$0.71** |

## Recursos Adicionales

- [Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [OpenSearch Documentation](https://docs.aws.amazon.com/opensearch-service/)
- [RAG Best Practices](https://aws.amazon.com/blogs/machine-learning/)

## Contacto y Soporte

Para problemas durante el taller:
1. Revisar logs con `make logs ALUMNO_ID=alumnoXX`
2. Verificar security groups y VPC endpoints
3. Confirmar IAM permissions
4. Consultar esta guía

¡Éxito con el taller!
