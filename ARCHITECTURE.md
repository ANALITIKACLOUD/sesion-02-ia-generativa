# Arquitectura Detallada - Taller RAG

## Vista General

Este documento describe la arquitectura completa del taller RAG, diseñada para 35 alumnos desplegando infraestructura serverless en AWS.

## Diagrama de Arquitectura Completa

```mermaid
graph TB
    subgraph "Infraestructura Compartida - Instructor"
        VPC[VPC 10.0.0.0/16]
        
        subgraph "Subnets Privadas"
            SN1[Subnet AZ-a<br/>10.0.0.0/24]
            SN2[Subnet AZ-b<br/>10.0.1.0/24]
        end
        
        subgraph "VPC Endpoints"
            VPE_BR[Bedrock Runtime<br/>Interface]
            VPE_S3[S3<br/>Gateway]
            VPE_CW[CloudWatch Logs<br/>Interface]
        end
        
        OS[OpenSearch<br/>Compartido]
        
        subgraph "Terraform Backend"
            S3_STATE[S3 Bucket<br/>terraform-state]
            DDB[DynamoDB<br/>terraform-locks]
        end
    end
    
    subgraph "Por Alumno - alumno01"
        S3_01[S3 Bucket<br/>rag-alumno01]
        L_01[Lambda<br/>rag-lambda-alumno01]
    end
    
    subgraph "Por Alumno - alumno02"
        S3_02[S3 Bucket<br/>rag-alumno02]
        L_02[Lambda<br/>rag-lambda-alumno02]
    end
    
    subgraph "Por Alumno - alumno35"
        S3_35[S3 Bucket<br/>rag-alumno35]
        L_35[Lambda<br/>rag-lambda-alumno35]
    end
    
    subgraph "Servicios AWS"
        BR[Bedrock<br/>Titan Embeddings]
        S3_SVC[S3 Service]
        CW[CloudWatch]
    end
    
    S3_01 -->|Trigger| L_01
    S3_02 -->|Trigger| L_02
    S3_35 -->|Trigger| L_35
    
    L_01 --> SN1
    L_02 --> SN1
    L_35 --> SN2
    
    SN1 --> VPE_BR
    SN2 --> VPE_BR
    VPE_BR --> BR
    
    SN1 --> VPE_S3
    SN2 --> VPE_S3
    VPE_S3 --> S3_SVC
    
    L_01 --> OS
    L_02 --> OS
    L_35 --> OS
    
    SN1 --> VPE_CW
    SN2 --> VPE_CW
    VPE_CW --> CW
    
    style VPC fill:#e1f5ff
    style OS fill:#ffebcc
    style BR fill:#d4edda
```

## Flujo de Datos - Indexación de Documentos

```mermaid
sequenceDiagram
    participant User as Alumno
    participant S3 as S3 Bucket
    participant Lambda as Lambda Function
    participant Bedrock as Bedrock
    participant OS as OpenSearch
    
    User->>S3: 1. Upload document.txt
    S3->>Lambda: 2. S3 Event Notification
    Lambda->>S3: 3. Get Object
    S3-->>Lambda: 4. Document content
    Lambda->>Bedrock: 5. Generate Embeddings
    Note over Lambda,Bedrock: Via VPC Endpoint
    Bedrock-->>Lambda: 6. Vector [1536 dims]
    Lambda->>OS: 7. Index document + vector
    Note over Lambda,OS: Direct VPC connection
    OS-->>Lambda: 8. Index confirmation
    Lambda-->>User: 9. Success response
```

## Flujo de Datos - Query RAG

```mermaid
sequenceDiagram
    participant User as Alumno
    participant Lambda as Lambda Function
    participant Bedrock as Bedrock
    participant OS as OpenSearch
    
    User->>Lambda: 1. Query: "¿Qué es RAG?"
    Lambda->>Bedrock: 2. Generate query embedding
    Bedrock-->>Lambda: 3. Query vector
    Lambda->>OS: 4. KNN Search (vector)
    OS-->>Lambda: 5. Top 3 similar documents
    Lambda-->>User: 6. Return results with scores
```

## Capas de Red y Seguridad

```mermaid
graph LR
    subgraph "VPC Privada"
        subgraph "Security Group Lambda"
            L[Lambda Functions]
        end
        
        subgraph "Security Group OpenSearch"
            OS[OpenSearch]
        end
        
        subgraph "Security Group VPC Endpoints"
            VPE[VPC Endpoints]
        end
    end
    
    L -->|HTTPS:443| OS
    L -->|HTTPS:443| VPE
    
    style L fill:#90caf9
    style OS fill:#ffcc80
    style VPE fill:#a5d6a7
```

### Reglas de Security Groups

#### Lambda SG (Egress)
```
Protocol: TCP
Port: 443
Destination: OpenSearch SG
Description: HTTPS to OpenSearch

Protocol: TCP
Port: 443
Destination: VPC Endpoints SG
Description: HTTPS to VPC Endpoints
```

#### OpenSearch SG (Ingress)
```
Protocol: TCP
Port: 443
Source: Lambda SG
Description: HTTPS from Lambda functions
```

#### VPC Endpoints SG (Ingress)
```
Protocol: TCP
Port: 443
Source: VPC CIDR (10.0.0.0/16)
Description: HTTPS from VPC
```

## IAM Permissions

### Lambda Execution Role

```mermaid
graph TD
    LR[Lambda Role] --> |Assume| Lambda[Lambda Service]
    LR --> P1[Policy: CloudWatch Logs]
    LR --> P2[Policy: VPC Access]
    LR --> P3[Policy: S3 Access]
    LR --> P4[Policy: Bedrock Access]
    LR --> P5[Policy: OpenSearch Access]
    
    P1 --> CW[CloudWatch]
    P2 --> VPC[VPC ENI Management]
    P3 --> S3[S3 Bucket]
    P4 --> BR[Bedrock]
    P5 --> OS[OpenSearch]
```

### Permisos Específicos

**S3 Access**
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject",
    "s3:ListBucket",
    "s3:PutObject"
  ],
  "Resource": [
    "arn:aws:s3:::rag-alumno01",
    "arn:aws:s3:::rag-alumno01/*"
  ]
}
```

**Bedrock Access**
```json
{
  "Effect": "Allow",
  "Action": ["bedrock:InvokeModel"],
  "Resource": "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v1"
}
```

**OpenSearch Access**
```json
{
  "Effect": "Allow",
  "Action": [
    "es:ESHttpGet",
    "es:ESHttpPost",
    "es:ESHttpPut",
    "es:ESHttpDelete"
  ],
  "Resource": "arn:aws:es:us-east-1:*:domain/taller-rag/*"
}
```

## Terraform State Management

```mermaid
graph TB
    subgraph "S3 Backend Structure"
        ROOT[taller-rag-terraform-state/]
        ROOT --> ALUMNOS[alumnos/]
        ALUMNOS --> A01[alumno01/terraform.tfstate]
        ALUMNOS --> A02[alumno02/terraform.tfstate]
        ALUMNOS --> A35[alumno35/terraform.tfstate]
    end
    
    subgraph "DynamoDB Locks"
        DDB[taller-rag-terraform-locks]
        DDB --> L1[LockID: alumno01]
        DDB --> L2[LockID: alumno02]
        DDB --> L3[LockID: alumno35]
    end
    
    A01 -.->|Lock| L1
    A02 -.->|Lock| L2
    A35 -.->|Lock| L3
```

## OpenSearch Index Structure

Cada alumno tiene su propio índice: `rag-alumno01`, `rag-alumno02`, etc.

```json
{
  "settings": {
    "index": {
      "knn": true,
      "number_of_shards": 1,
      "number_of_replicas": 0
    }
  },
  "mappings": {
    "properties": {
      "text": {
        "type": "text"
      },
      "embedding": {
        "type": "knn_vector",
        "dimension": 1536
      },
      "metadata": {
        "type": "object"
      },
      "timestamp": {
        "type": "date"
      }
    }
  }
}
```

### Ejemplo de Documento Indexado

```json
{
  "_index": "rag-alumno01",
  "_id": "documents/sample.txt",
  "_source": {
    "text": "Este es un documento sobre RAG...",
    "embedding": [0.123, -0.456, 0.789, ...],
    "metadata": {
      "bucket": "rag-alumno01",
      "key": "documents/sample.txt"
    },
    "timestamp": "2025-11-10T15:30:00Z"
  }
}
```

## Escala y Límites

### Por Alumno
- **Lambda**: 1 función
- **S3 Bucket**: 1 bucket
- **OpenSearch Index**: 1 índice

### Compartido (todos los alumnos)
- **VPC**: 1 VPC
- **Subnets**: 2 subnets privadas
- **VPC Endpoints**: 3 endpoints
- **OpenSearch Domain**: 1 dominio

### Service Quotas a Verificar

| Servicio | Quota | Mínimo Requerido |
|----------|-------|------------------|
| VPC Endpoints | Per Region | 5 |
| Lambda Concurrent Executions | Per Region | 100 |
| OpenSearch Instances | Per Region | 1 |
| S3 Buckets | Per Account | 40 |

## Optimizaciones de Costos

1. **OpenSearch**: Single-AZ, t3.small (desarrollo)
2. **VPC Endpoints**: Solo los necesarios (Bedrock, S3, Logs)
3. **Lambda**: Memoria optimizada (512MB)
4. **S3**: Lifecycle para limpiar versiones antiguas

## Consideraciones de Seguridad

1. **Network Isolation**: Lambdas en VPC privada
2. **No Public IPs**: Todo el tráfico interno
3. **Encryption**: S3 y OpenSearch con encryption at rest
4. **TLS**: OpenSearch con enforce HTTPS
5. **Fine-grained Access**: IAM roles con least privilege
6. **Secrets Management**: OpenSearch password en SSM Parameter Store

## Failover y Alta Disponibilidad

Para producción (no implementado en el taller):

- Multi-AZ OpenSearch
- Lambda en múltiples subnets
- NAT Gateway con failover
- S3 cross-region replication

## Monitoreo

```mermaid
graph LR
    L[Lambda] -->|Logs| CW[CloudWatch Logs]
    L -->|Metrics| CWM[CloudWatch Metrics]
    OS[OpenSearch] -->|Logs| CW
    OS -->|Metrics| CWM
    
    CW --> DASH[CloudWatch Dashboard]
    CWM --> DASH
    
    DASH --> |Alerts| SNS[SNS Topic]
```

### Métricas Clave

**Lambda**
- Invocations
- Duration
- Errors
- Throttles

**OpenSearch**
- ClusterStatus
- SearchRate
- IndexingRate
- CPUUtilization

## Troubleshooting Decision Tree

```mermaid
graph TD
    START[Error en Lambda] --> Q1{¿Timeout?}
    Q1 -->|Sí| CHECK_VPC[Verificar VPC Endpoints]
    Q1 -->|No| Q2{¿Permission denied?}
    
    CHECK_VPC --> VPC_OK{¿Endpoints activos?}
    VPC_OK -->|No| FIX_VPC[Recrear VPC Endpoints]
    VPC_OK -->|Sí| CHECK_SG[Verificar Security Groups]
    
    Q2 -->|Sí| CHECK_IAM[Verificar IAM Role]
    Q2 -->|No| CHECK_LOGS[Revisar CloudWatch Logs]
    
    CHECK_IAM --> IAM_POLICY[Actualizar Policies]
    CHECK_LOGS --> DEBUG[Debug específico]
```

## Referencias

- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Amazon Bedrock](https://docs.aws.amazon.com/bedrock/)
- [Amazon OpenSearch](https://docs.aws.amazon.com/opensearch-service/)
- [AWS Lambda in VPC](https://docs.aws.amazon.com/lambda/latest/dg/configuration-vpc.html)
