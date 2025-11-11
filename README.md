# Taller RAG con AWS - Arquitectura Serverless

## Objetivo
Cada participante desplegará su propia infraestructura RAG (Retrieval Augmented Generation) usando Bedrock, Lambda, S3 y OpenSearch compartido.

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│ VPC Compartida (desplegada por instructor)              │
│                                                           │
│  ┌──────────────────────────────────────────┐           │
│  │ Subnet Privada                            │           │
│  │                                            │           │
│  │  Lambda alumno-01  ┐                     │           │
│  │  Lambda alumno-02  ├─→ Security Group    │           │
│  │  Lambda alumno-XX  ┘                     │           │
│  │                                            │           │
│  │  OpenSearch (compartido) ← SG            │           │
│  └──────────────────────────────────────────┘           │
│                                                           │
│  VPC Endpoints (compartidos):                            │
│  ├─ Bedrock Runtime (embeddings)                        │
│  ├─ S3 Gateway                                          │
│  └─ CloudWatch Logs                                     │
└─────────────────────────────────────────────────────────┘

Cada alumno:
├── S3 Bucket (rag-alumno-XX)
└── Lambda (rag-lambda-alumno-XX)
    ├── Lee documentos de S3
    ├── Genera embeddings con Bedrock
    └── Indexa en OpenSearch (índice separado)
```

## Pre-requisitos (instructor)

### 1. Levantar infraestructura compartida
```bash
cd shared/
terraform init
terraform apply
```

Esto crea:
- VPC con subnets privadas
- VPC Endpoints (Bedrock, S3, CloudWatch)
- OpenSearch domain
- Security Groups base
- S3 backend para Terraform states de alumnos

### 2. Capturar outputs
```bash
terraform output -json > ../shared-outputs.json
```

## Instrucciones para participantes

### Setup inicial
```bash
# 1. Clonar repositorio
git clone <repo-url>
cd a/student

# 2. IMPORTANTE: Empaquetar Lambda con dependencias
cd ../lambda
chmod +x build.sh
./build.sh

# 3. Configurar tu ID de alumno
cd ../student
export STUDENT_ID="alumno01"  # Cambiar según asignación

# 4. Copiar archivo de variables
cp terraform.tfvars.example terraform.tfvars

# 5. Editar terraform.tfvars con tu STUDENT_ID
vim terraform.tfvars
```

### Desplegar infraestructura
```bash
# Inicializar con tu student_id
terraform init -backend-config="key=students/${STUDENT_ID}/terraform.tfstate"

# Aplicar
terraform apply
```

### Probar el RAG
```bash
# 1. Subir documento de prueba a tu bucket
aws s3 cp sample-doc.txt s3://rag-${STUDENT_ID}/documents/

# 2. Invocar Lambda para indexar
aws lambda invoke \
  --function-name rag-lambda-${STUDENT_ID} \
  --payload '{"action": "index", "document": "sample-doc.txt"}' \
  response.json

# 3. Hacer una query
aws lambda invoke \
  --function-name rag-lambda-${STUDENT_ID} \
  --payload '{"action": "query", "question": "¿De qué trata el documento?"}' \
  response.json
```

### Limpieza
```bash
terraform destroy
```

## Estructura del proyecto

```
.
├── shared/                   # Infraestructura compartida (instructor)
│   ├── vpc.tf
│   ├── vpc_endpoints.tf
│   ├── opensearch.tf
│   ├── security_groups.tf
│   ├── backend.tf
│   └── outputs.tf
│
├── student/                  # Infraestructura por alumno
│   ├── backend.tf
│   ├── variables.tf
│   ├── terraform.tfvars.example
│   ├── lambda.tf
│   ├── s3.tf
│   └── iam.tf
│
├── lambda/                   # Código del Lambda (común)
│   ├── index.py
│   ├── requirements.txt
│   └── rag_logic.py
│
└── scripts/                  # Utilidades
    ├── setup-student.sh
    └── cleanup-all.sh
```

## Costos estimados

| Recurso | Cantidad | Costo mensual |
|---------|----------|---------------|
| VPC | 1 | Gratis |
| VPC Endpoint Bedrock | 1 | ~$7 |
| VPC Endpoint S3 | 1 | Gratis |
| OpenSearch t3.small | 1 | ~$35 |
| Lambda (tier gratis) | 35 | ~Gratis |
| S3 (pocos MB) | 35 | ~$0.10 |
| **Total taller 4h** | | **~$1** |

## Notas importantes

1. **Parametrización**: Cada alumno usa su `STUDENT_ID` único para evitar conflictos
2. **OpenSearch compartido**: Cada alumno escribe en su índice `rag-{student_id}`
3. **Lambda privado**: Sin acceso a internet, solo a servicios AWS vía VPC endpoints
4. **Terraform state**: Backend S3 compartido con key por alumno

## Troubleshooting

### Lambda no puede conectarse a Bedrock
- Verificar que el VPC endpoint esté activo
- Revisar security group del Lambda

### No hay permisos para escribir en OpenSearch
- Verificar IAM role del Lambda incluye permisos de OpenSearch
- Confirmar que el security group permite tráfico desde Lambda SG

### Terraform state lock
```bash
# Ver locks activos
aws dynamodb scan --table-name taller-rag-locks

# Liberar lock (con cuidado)
terraform force-unlock <lock-id>
```
