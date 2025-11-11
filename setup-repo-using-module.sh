#!/bin/bash
set -e

# ============================================
# Script para crear repositorio que USA el módulo
# ============================================

REPO_NAME="aws-lab-glue-athena"

echo "🚀 Creando repositorio que usa el módulo IAM Users..."
echo ""

# Crear estructura
mkdir -p "${REPO_NAME}"
cd "${REPO_NAME}"

mkdir -p environments/dev
mkdir -p environments/staging
mkdir -p environments/prod
mkdir -p scripts
mkdir -p docs

# ============================================
# ARCHIVO: main.tf (raíz)
# ============================================
cat > main.tf << 'EOF'
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Backend remoto (opcional)
  # backend "s3" {
  #   bucket         = "mi-terraform-state"
  #   key            = "lab-glue-athena/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "Lab-Glue-Athena"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}

# ============================================
# MÓDULO IAM USERS (desde GitHub o local)
# ============================================
module "iam_users" {
  # Opción 1: Módulo local
  source = "../IAM-users-module"
  
  # Opción 2: Módulo desde GitHub (cuando lo subas)
  # source = "git::https://github.com/tu-org/terraform-aws-iam-users.git?ref=v1.0.0"
  
  # Opción 3: Terraform Registry (si lo publicas)
  # source  = "tu-org/iam-users/aws"
  # version = "1.0.0"

  groups        = var.groups
  users         = var.users
  default_group = var.default_group
  common_tags   = var.common_tags
}

# ============================================
# S3 BUCKET PARA EL LABORATORIO
# ============================================
resource "aws_s3_bucket" "lab_data" {
  bucket = "${var.project_name}-${var.environment}-data"

  tags = {
    Name = "Laboratorio Glue Athena - Data"
  }
}

resource "aws_s3_bucket_versioning" "lab_data" {
  bucket = aws_s3_bucket.lab_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================
# GLUE DATABASE
# ============================================
resource "aws_glue_catalog_database" "lab" {
  name        = "${var.project_name}_${var.environment}"
  description = "Database para laboratorio Glue y Athena"
}

# ============================================
# IAM ROLE PARA GLUE
# ============================================
resource "aws_iam_role" "glue_role" {
  name = "${var.project_name}-${var.environment}-glue-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "Glue Service Role"
  }
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy_attachment" "glue_s3" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# ============================================
# ATHENA WORKGROUP
# ============================================
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.project_name}-${var.environment}-athena-results"

  tags = {
    Name = "Athena Query Results"
  }
}

resource "aws_athena_workgroup" "lab" {
  name = "${var.project_name}-${var.environment}"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/"
    }
  }

  tags = {
    Name = "Workgroup para laboratorio"
  }
}
EOF

# ============================================
# ARCHIVO: variables.tf
# ============================================
cat > variables.tf << 'EOF'
variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "lab-glue-athena"
}

# Variables del módulo IAM
variable "groups" {
  description = "IAM groups configuration"
  type = map(object({
    policy_arns = list(string)
  }))
}

variable "users" {
  description = "IAM users configuration"
  type = map(object({
    console_access       = optional(bool, false)
    create_access_key    = optional(bool, false)
    force_password_reset = optional(bool, true)
    groups               = optional(list(string), [])
    tags                 = optional(map(string), {})
  }))
}

variable "default_group" {
  description = "Default group for all users"
  type        = string
  default     = null
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
EOF

# ============================================
# ARCHIVO: outputs.tf
# ============================================
cat > outputs.tf << 'EOF'
# Outputs del módulo IAM
output "users" {
  description = "Created IAM users"
  value       = module.iam_users.user_names
}

output "groups" {
  description = "Created IAM groups"
  value       = module.iam_users.group_names
}

output "passwords" {
  description = "User passwords (SENSITIVE)"
  sensitive   = true
  value       = module.iam_users.passwords
}

output "access_keys" {
  description = "User access keys (SENSITIVE)"
  sensitive   = true
  value       = module.iam_users.access_keys
}

# Outputs de infraestructura
output "s3_data_bucket" {
  description = "S3 bucket for lab data"
  value       = aws_s3_bucket.lab_data.id
}

output "s3_athena_results_bucket" {
  description = "S3 bucket for Athena results"
  value       = aws_s3_bucket.athena_results.id
}

output "glue_database" {
  description = "Glue catalog database"
  value       = aws_glue_catalog_database.lab.name
}

output "glue_role_arn" {
  description = "IAM role for Glue jobs"
  value       = aws_iam_role.glue_role.arn
}

output "athena_workgroup" {
  description = "Athena workgroup"
  value       = aws_athena_workgroup.lab.name
}

output "console_url" {
  description = "AWS Console URL"
  value       = "https://console.aws.amazon.com/"
}
EOF

# ============================================
# ARCHIVO: terraform.tfvars
# ============================================
cat > terraform.tfvars << 'EOF'
aws_region   = "us-east-1"
environment  = "dev"
project_name = "lab-glue-athena"

# Grupos IAM
groups = {
  laboratorio_glue_athena = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AWSGlueConsoleFullAccess",
      "arn:aws:iam::aws:policy/AmazonAthenaFullAccess",
      "arn:aws:iam::aws:policy/AmazonS3FullAccess",
      "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess",
      "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
    ]
  }
}

default_group = "laboratorio_glue_athena"

# Usuarios (5 de ejemplo - agregar los 35 completos)
users = {
  jose_huapaya = {
    console_access = true
    tags = {
      Name = "Jose Alberto Huapaya Vasquez"
      Role = "Participante"
    }
  }
  
  liz_quiroz = {
    console_access = true
    tags = {
      Name = "Liz Fiorella Quiroz Sotelo"
      Role = "Participante"
    }
  }
  
  lizell_condori = {
    console_access = true
    tags = {
      Name = "Lizell Nieves Condori Cabana"
      Role = "Participante"
    }
  }
  
  nataly_vasquez = {
    console_access = true
    tags = {
      Name = "Nataly Grace Vasquez Saenz"
      Role = "Participante"
    }
  }
  
  monica_rantes = {
    console_access = true
    tags = {
      Name = "Monica Tahiz Rantes Garcia"
      Role = "Participante"
    }
  }
  
  # ... agregar los 30 usuarios restantes aquí
}

common_tags = {
  Project     = "Lab-Glue-Athena"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Duracion    = "3-horas"
}
EOF

# ============================================
# ARCHIVO: README.md
# ============================================
cat > README.md << 'EOF'
# AWS Lab - Glue & Athena

Laboratorio de AWS Data & Analytics usando Glue y Athena.

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                   IAM Users (35)                        │
│              (Módulo reutilizable)                      │
└─────────────────────────────────────────────────────────┘
                          │
                          │ Permisos
                          ↓
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  ┌──────────┐      ┌───────────┐      ┌─────────┐    │
│  │    S3    │ ───→ │   Glue    │ ───→ │ Athena  │    │
│  │  Bucket  │      │  Crawler  │      │ Queries │    │
│  └──────────┘      └───────────┘      └─────────┘    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## 📁 Estructura

```
aws-lab-glue-athena/
├── main.tf              # Módulo IAM + Infra AWS
├── variables.tf         # Variables
├── outputs.tf           # Outputs
├── terraform.tfvars     # Configuración
├── README.md
├── environments/
│   ├── dev/
│   ├── staging/
│   └── prod/
├── scripts/
│   ├── deploy.sh
│   ├── get-credentials.sh
│   └── cleanup.sh
└── docs/
    └── LABORATORIO.md
```

## 🚀 Uso

### Requisitos

- Terraform >= 1.5.0
- AWS CLI configurado
- Módulo IAM Users (en `../IAM-users-module/`)

### Deployment

```bash
# Inicializar
terraform init

# Ver plan
terraform plan

# Aplicar
terraform apply

# Ver credenciales
terraform output -json passwords | jq
```

### Obtener credenciales

```bash
# Todas las passwords
terraform output -json passwords | jq -r 'to_entries[] | "\(.key): \(.value)"'

# CSV para distribuir
terraform output -json passwords | jq -r 'to_entries[] | "\(.key),\(.value)"' > credenciales.csv
```

## 🔑 Permisos

Los usuarios tienen acceso a:

- ✅ AWS Glue (Crawlers, Jobs, Databases)
- ✅ Amazon Athena (Query Editor)
- ✅ Amazon S3 (Data upload/download)
- ✅ CloudWatch Logs (View logs)
- ✅ IAM Read-Only (View roles)

## 🧪 Actividades

### 1. Subir datos a S3

```bash
aws s3 cp datos.csv s3://lab-glue-athena-dev-data/input/
```

### 2. Crear Crawler en Glue

- Console → AWS Glue → Crawlers
- Configurar origen: S3 bucket
- Ejecutar crawler

### 3. Consultar con Athena

```sql
SELECT * FROM mi_tabla LIMIT 10;
```

## 🗑️ Cleanup

```bash
# Eliminar usuarios y recursos
terraform destroy
```

## 📊 Outputs

```bash
# Infraestructura creada
terraform output s3_data_bucket
terraform output glue_database
terraform output athena_workgroup

# Usuarios creados
terraform output users
```

## 🔗 Referencias

- [Módulo IAM Users](../IAM-users-module/)
- [AWS Glue Docs](https://docs.aws.amazon.com/glue/)
- [Amazon Athena Docs](https://docs.aws.amazon.com/athena/)
EOF

# ============================================
# ARCHIVO: scripts/deploy.sh
# ============================================
cat > scripts/deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Deploying Lab Glue & Athena..."

# Verificar módulo existe
if [ ! -d "../IAM-users-module" ]; then
    echo "❌ Error: Módulo IAM Users no encontrado"
    echo "   Expected: ../IAM-users-module/"
    exit 1
fi

# Terraform workflow
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
rm -f tfplan

# Generar credenciales
echo ""
echo "📋 Generando archivo de credenciales..."
terraform output -json passwords | jq -r 'to_entries[] | "\(.key): \(.value)"' > credenciales.txt
echo "✅ Credenciales guardadas en: credenciales.txt"

# Mostrar outputs importantes
echo ""
echo "📊 Recursos creados:"
terraform output s3_data_bucket
terraform output glue_database
terraform output athena_workgroup

echo ""
echo "✅ Deployment completado"
EOF
chmod +x scripts/deploy.sh

# ============================================
# ARCHIVO: scripts/cleanup.sh
# ============================================
cat > scripts/cleanup.sh << 'EOF'
#!/bin/bash
set -e

echo "🗑️  Eliminando recursos del laboratorio..."

# Advertencia
read -p "⚠️  Esto eliminará TODOS los usuarios y recursos. ¿Continuar? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Cancelado"
    exit 0
fi

# Destruir
terraform destroy -auto-approve

# Limpiar archivos locales
rm -f credenciales.txt
rm -f terraform.tfstate.backup
rm -rf .terraform/

echo "✅ Cleanup completado"
EOF
chmod +x scripts/cleanup.sh

# ============================================
# ARCHIVO: .gitignore
# ============================================
cat > .gitignore << 'EOF'
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfplan
*.tfvars
!terraform.tfvars.example

# Credenciales
credenciales.txt
credenciales.csv
passwords.txt

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
EOF

# ============================================
# ARCHIVO: docs/LABORATORIO.md
# ============================================
cat > docs/LABORATORIO.md << 'EOF'
# Guía del Laboratorio - AWS Glue y Athena

## 🎯 Objetivos

Al finalizar este laboratorio podrás:

1. Crear un Data Catalog con Glue
2. Ejecutar Crawlers para descubrir esquemas
3. Crear y ejecutar Glue Jobs (ETL PySpark)
4. Consultar datos con Athena SQL
5. Aplicar buenas prácticas de particionamiento y costos

## 📋 Actividades

### Actividad 1: Cargar CSV a S3 (15 min)

**Paso 1:** Obtener bucket name
```bash
terraform output s3_data_bucket
```

**Paso 2:** Subir archivo CSV
```bash
aws s3 cp datos.csv s3://BUCKET_NAME/input/datos.csv
```

**Paso 3:** Verificar en Console
- S3 → Buckets → Ver archivo

---

### Actividad 2: Crear Crawler en Glue (20 min)

**Paso 1:** Ir a AWS Glue Console
- Servicios → AWS Glue → Crawlers

**Paso 2:** Crear Crawler
- Name: `crawler-lab-csv`
- Data source: S3 → `s3://BUCKET_NAME/input/`
- IAM Role: Usar el role creado por Terraform
- Database: Seleccionar database creada

**Paso 3:** Ejecutar Crawler
- Run crawler → Esperar 2-3 minutos

**Paso 4:** Ver tabla creada
- Glue → Tables → Ver esquema inferido

---

### Actividad 3: Consultar con Athena (20 min)

**Paso 1:** Ir a Amazon Athena Console

**Paso 2:** Configurar workgroup
```
Settings → Workgroup: lab-glue-athena-dev
```

**Paso 3:** Ejecutar queries
```sql
-- Ver primeras 10 filas
SELECT * FROM nombre_tabla LIMIT 10;

-- Contar registros
SELECT COUNT(*) FROM nombre_tabla;

-- Agrupar por columna
SELECT columna, COUNT(*) 
FROM nombre_tabla 
GROUP BY columna;
```

---

### Actividad 4: Glue Job ETL (30 min)

**Paso 1:** Crear Glue Job
- Glue → ETL Jobs → Visual ETL
- Source: S3 (tabla del crawler)
- Transform: Agregar transformaciones
- Target: S3 (nueva ubicación)

**Paso 2:** Ejecutar Job
- Run Job → Ver logs en CloudWatch

**Paso 3:** Verificar output
- S3 → Ver archivos procesados

---

## 💰 Buenas Prácticas - Costos

### Particionar datos

```python
# En Glue Job PySpark
df.write.partitionBy("year", "month").parquet("s3://output/")
```

### Usar formatos comprimidos

- CSV → Parquet (10x más rápido)
- JSON → ORC (mejor compresión)

### Limitar queries en Athena

```sql
-- ❌ MAL (escanea todo)
SELECT * FROM tabla;

-- ✅ BIEN (solo columnas necesarias)
SELECT col1, col2 FROM tabla WHERE year=2024;
```

---

## 🔍 Troubleshooting

### Crawler no encuentra datos
- Verificar path en S3
- Verificar permisos del IAM role

### Query falla en Athena
- Verificar sintaxis SQL
- Verificar database seleccionada
- Verificar particiones

### Glue Job falla
- Ver logs en CloudWatch
- Verificar permisos de escritura en S3

---

## 📚 Referencias

- [AWS Glue Developer Guide](https://docs.aws.amazon.com/glue/)
- [Amazon Athena User Guide](https://docs.aws.amazon.com/athena/)
- [PySpark Documentation](https://spark.apache.org/docs/latest/api/python/)
EOF

echo ""
echo "✅ Repositorio creado: ${REPO_NAME}/"
echo ""
echo "📁 Estructura:"
tree -L 3 "${REPO_NAME}" 2>/dev/null || find "${REPO_NAME}" -type f | sort

echo ""
echo "🚀 Próximos pasos:"
echo ""
echo "1. cd ${REPO_NAME}"
echo "2. Editar terraform.tfvars (agregar los 35 usuarios)"
echo "3. ./scripts/deploy.sh"
echo "4. Compartir docs/LABORATORIO.md con participantes"
echo ""