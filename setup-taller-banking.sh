#!/bin/bash

# =============================================================================
# SCRIPT: Setup Taller Banking - Estructura Completa
# =============================================================================
# Genera toda la estructura de carpetas y archivos para el taller
# Autor: JA - Analitika Cloud
# Fecha: 2025-01-04
# =============================================================================

set -e  # Exit on error

echo "=================================================="
echo "🚀 TALLER BANKING - GENERADOR DE ESTRUCTURA"
echo "=================================================="
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para crear directorios
create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        echo -e "${GREEN}✓${NC} Directorio creado: $1"
    else
        echo -e "${YELLOW}→${NC} Directorio existe: $1"
    fi
}

# Función para crear archivo
create_file() {
    touch "$1"
    echo -e "${GREEN}✓${NC} Archivo creado: $1"
}

echo "📁 Creando estructura de directorios..."
echo ""

# Crear estructura de directorios
create_dir "taller-banking"
cd taller-banking

create_dir "terraform"
create_dir "terraform/sql"
create_dir "cloud_functions/sql_to_bq"
create_dir "scripts"
create_dir "data"
create_dir "docs"

echo ""
echo "📝 Generando archivos de configuración..."
echo ""

# =============================================================================
# 1. ROOT FILES
# =============================================================================

# .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
env/
.venv

# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
.terraform.lock.hcl

# Credentials
*.json
credentials/
secrets/
.env
*.pem
*.key

# Cloud Functions
cloud_functions/**/*.zip

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo

# Data
data/*.csv
!data/.gitkeep
EOF

echo -e "${GREEN}✓${NC} Generado: .gitignore"

# .env.example
cat > .env.example << 'EOF'
# =============================================================================
# TALLER BANKING - VARIABLES DE ENTORNO
# =============================================================================
# Copiar este archivo a .env y completar con valores reales
# NUNCA commitear el archivo .env a Git

# GCP Project
PROJECT_ID=tu-proyecto-gcp
REGION=us-east4

# Cloud SQL Server
DB_HOST=34.123.45.67  # Obtener después de terraform apply
DB_PORT=1433
DB_NAME=banking_taller
DB_USER=sqlserver
DB_PASS=change_me_secure_password

# BigQuery
BQ_DATASET_RDV=taller_banking_rdv
BQ_DATASET_UDV=taller_banking_udv
BQ_DATASET_DDV=taller_banking_ddv
EOF

echo -e "${GREEN}✓${NC} Generado: .env.example"

# README.md
cat > README.md << 'EOF'
# 🏦 Taller Banking - Arquitectura de Datos

## 📋 Descripción

Taller práctico de arquitectura de datos para 35 participantes.
Stack: SQL Server → BigQuery (RDV → UDV → DDV) con Cloud Functions.

## 🏗️ Arquitectura
```
CSV Files
    ↓
SQL Server (Cloud SQL)
    ↓ (Cloud Function cada hora)
BigQuery RDV (Raw Data Vault)
    ↓ (Scheduled Query)
BigQuery UDV (User Data Vault - Clean)
    ↓ (Scheduled Query)
BigQuery DDV (Data Delivery Vault - KPIs)
```

## 🚀 Quick Start

### 1. Preparar entorno
```bash
# Clonar/crear estructura
./setup-taller-banking.sh

# Configurar variables
cp .env.example .env
# Editar .env con tus valores
```

### 2. Desplegar infraestructura
```bash
cd terraform

# Configurar Terraform
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars

# Desplegar
terraform init
terraform plan
terraform apply
```

### 3. Cargar datos a SQL Server
```bash
# Instalar dependencias Python
cd scripts
pip install -r requirements.txt

# Cargar CSVs a SQL Server
python load_csv_to_sqlserver.py
```

### 4. Verificar sincronización
```bash
# Trigger manual Cloud Function
FUNCTION_URL=$(terraform output -raw cloud_function_url)
curl -X POST $FUNCTION_URL \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)"

# Verificar en BigQuery
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) FROM `taller_banking_rdv.transacciones_raw`'
```

## 📊 Datasets y Tablas

### RDV (Raw Data Vault)
- `transacciones_raw` - Transacciones sin procesar
- `clientes_raw` - Clientes sin procesar

### UDV (User Data Vault)
- `transacciones_clean` - Transacciones limpias y validadas
- `clientes_clean` - Clientes limpios
- `transacciones_rejected` - Registros rechazados

### DDV (Data Delivery Vault)
- `kpi_transaccional_diario` - Métricas diarias
- `kpi_cliente_segmento` - Análisis por segmento
- `anomalias_monto` - Detección de anomalías

## 🎓 Para Participantes

### Credenciales de acceso

Después del deployment, compartir:
```
SQL Server:
- Host: [OBTENER DE TERRAFORM OUTPUT]
- Port: 1433
- Database: banking_taller
- User: sqlserver
- Password: [CONFIGURADO EN TERRAFORM]

BigQuery:
- Project: [TU_PROJECT_ID]
- Dataset RDV: taller_banking_rdv
- Dataset UDV: taller_banking_udv
- Dataset DDV: taller_banking_ddv
```

## 💰 Costos Estimados

- **Taller 8 horas:** ~$2.50 USD
- **Mensual (si dejas activo):** ~$80 USD

**IMPORTANTE:** Destruir recursos después del taller:
```bash
terraform destroy
```

## 📚 Documentación

- [Arquitectura Detallada](docs/architecture.md)
- [Guía de Troubleshooting](docs/troubleshooting.md)
- [Queries de Ejemplo](docs/sample-queries.md)

## 🔗 Referencias

- [Golden Rules](https://github.com/tu-org/golden-rules)
- [BigQuery Best Practices](https://cloud.google.com/bigquery/docs/best-practices)
EOF

echo -e "${GREEN}✓${NC} Generado: README.md"

# Makefile
cat > Makefile << 'EOF'
.PHONY: help setup deploy test clean

help:
	@echo "Taller Banking - Comandos disponibles:"
	@echo ""
	@echo "  make setup     - Instalar dependencias"
	@echo "  make deploy    - Desplegar infraestructura"
	@echo "  make load      - Cargar datos a SQL Server"
	@echo "  make sync      - Sincronizar SQL → BigQuery"
	@echo "  make test      - Ejecutar tests"
	@echo "  make clean     - Limpiar archivos temporales"
	@echo "  make destroy   - Destruir infraestructura"

setup:
	@echo "📦 Instalando dependencias..."
	pip install -r scripts/requirements.txt
	cd terraform && terraform init

deploy:
	@echo "🚀 Desplegando infraestructura..."
	cd terraform && terraform apply -auto-approve

load:
	@echo "📊 Cargando datos a SQL Server..."
	python scripts/load_csv_to_sqlserver.py

sync:
	@echo "🔄 Sincronizando SQL → BigQuery..."
	$(eval FUNCTION_URL=$(shell cd terraform && terraform output -raw cloud_function_url))
	curl -X POST $(FUNCTION_URL) \
	  -H "Authorization: Bearer $(shell gcloud auth print-identity-token)"

test:
	@echo "🧪 Ejecutando tests..."
	python scripts/test_connection.py

clean:
	@echo "🧹 Limpiando archivos temporales..."
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache

destroy:
	@echo "💥 DESTRUYENDO infraestructura..."
	@echo "⚠️  Esto eliminará TODOS los recursos"
	@read -p "¿Estás seguro? (yes/no): " confirm && [ "$$confirm" = "yes" ]
	cd terraform && terraform destroy
EOF

echo -e "${GREEN}✓${NC} Generado: Makefile"

# docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # SQL Server local para testing
  sqlserver:
    image: mcr.microsoft.com/mssql/server:2019-latest
    container_name: taller_sqlserver_local
    environment:
      ACCEPT_EULA: "Y"
      SA_PASSWORD: "TallerBanking2024!"
      MSSQL_PID: "Developer"
    ports:
      - "1433:1433"
    volumes:
      - sqlserver_data:/var/opt/mssql
    healthcheck:
      test: /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "TallerBanking2024!" -Q "SELECT 1"
      interval: 10s
      timeout: 5s
      retries: 5

  # BigQuery Emulator para testing
  bigquery-emulator:
    image: ghcr.io/goccy/bigquery-emulator:latest
    container_name: taller_bigquery_emulator
    ports:
      - "9050:9050"
      - "9060:9060"
    command: 
      - --project=taller-banking-local
      - --dataset=banking_rdv,banking_udv,banking_ddv
    volumes:
      - ./data:/data

volumes:
  sqlserver_data:
EOF

echo -e "${GREEN}✓${NC} Generado: docker-compose.yml"

# =============================================================================
# 2. TERRAFORM FILES
# =============================================================================

echo ""
echo "📝 Generando archivos Terraform..."
echo ""

# terraform/variables.tf
cat > terraform/variables.tf << 'EOF'
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-east4"
}

variable "taller_prefix" {
  description = "Prefijo para todos los recursos"
  type        = string
  default     = "taller-banking"
}

variable "sql_password" {
  description = "Password para SQL Server"
  type        = string
  sensitive   = true
}

variable "participants_count" {
  description = "Número de participantes del taller"
  type        = number
  default     = 35
}

variable "sql_tier" {
  description = "Tier de Cloud SQL"
  type        = string
  default     = "db-custom-2-7680"  # 2 vCPU, 7.6GB RAM
}

variable "enable_deletion_protection" {
  description = "Protección contra borrado accidental"
  type        = bool
  default     = false  # Para taller, permitir delete fácil
}
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/variables.tf"

# terraform/main.tf
cat > terraform/main.tf << 'EOF'
terraform {
  required_version = ">= 1.5"
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "bigquery.googleapis.com",
    "cloudfunctions.googleapis.com",
    "cloudbuild.googleapis.com",
    "storage-api.googleapis.com",
    "cloudscheduler.googleapis.com",
    "secretmanager.googleapis.com",
    "bigquerydatatransfer.googleapis.com"
  ])
  
  service            = each.key
  disable_on_destroy = false
}

# Random suffix para recursos únicos
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  resource_suffix = random_id.suffix.hex
  full_prefix     = "${var.taller_prefix}-${local.resource_suffix}"
}
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/main.tf"

# terraform/cloudsql.tf
cat > terraform/cloudsql.tf << 'EOF'
# Cloud SQL SQL Server Instance
resource "google_sql_database_instance" "taller_sqlserver" {
  name             = "${var.taller_prefix}-sqlserver-${random_id.suffix.hex}"
  database_version = "SQLSERVER_2019_STANDARD"
  region           = var.region
  
  settings {
    tier              = var.sql_tier
    disk_size         = 50  # GB
    disk_type         = "PD_SSD"
    availability_type = "ZONAL"
    
    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      point_in_time_recovery_enabled = false
    }
    
    ip_configuration {
      ipv4_enabled = true
      require_ssl  = false
      
      # SOLO PARA TALLER: Acceso desde cualquier IP
      authorized_networks {
        name  = "allow-all-taller"
        value = "0.0.0.0/0"
      }
    }
    
    insights_config {
      query_insights_enabled  = true
      query_plans_per_minute  = 5
      query_string_length     = 1024
      record_application_tags = false
      record_client_address   = false
    }
    
    database_flags {
      name  = "contained database authentication"
      value = "on"
    }
  }
  
  deletion_protection = var.enable_deletion_protection
  
  depends_on = [google_project_service.required_apis]
}

# Database
resource "google_sql_database" "banking_taller" {
  name     = "banking_taller"
  instance = google_sql_database_instance.taller_sqlserver.name
}

# User
resource "google_sql_user" "sqlserver_user" {
  name     = "sqlserver"
  instance = google_sql_database_instance.taller_sqlserver.name
  password = var.sql_password
}
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/cloudsql.tf"

# terraform/bigquery.tf
cat > terraform/bigquery.tf << 'EOF'
# Dataset: RDV
resource "google_bigquery_dataset" "banking_rdv" {
  dataset_id    = "taller_banking_rdv"
  friendly_name = "Banking RDV - Raw Data Vault"
  description   = "Capa RDV: Datos sin procesar del taller"
  location      = var.region
  
  labels = {
    taller = "banking"
    layer  = "rdv"
  }
}

# Dataset: UDV
resource "google_bigquery_dataset" "banking_udv" {
  dataset_id    = "taller_banking_udv"
  friendly_name = "Banking UDV - User Data Vault"
  description   = "Capa UDV: Datos limpios y validados"
  location      = var.region
  
  labels = {
    taller = "banking"
    layer  = "udv"
  }
}

# Dataset: DDV
resource "google_bigquery_dataset" "banking_ddv" {
  dataset_id    = "taller_banking_ddv"
  friendly_name = "Banking DDV - Data Delivery Vault"
  description   = "Capa DDV: KPIs y agregaciones"
  location      = var.region
  
  labels = {
    taller = "banking"
    layer  = "ddv"
  }
}

# Tabla RDV: transacciones_raw
resource "google_bigquery_table" "transacciones_raw" {
  dataset_id = google_bigquery_dataset.banking_rdv.dataset_id
  table_id   = "transacciones_raw"
  
  time_partitioning {
    type  = "DAY"
    field = "ingestion_timestamp"
  }
  
  clustering = ["id_cliente", "tipo_transaccion"]
  
  schema = jsonencode([
    { name = "id_cliente", type = "STRING", mode = "NULLABLE" },
    { name = "fecha_transaccion", type = "STRING", mode = "NULLABLE" },
    { name = "tipo_transaccion", type = "STRING", mode = "NULLABLE" },
    { name = "monto", type = "FLOAT64", mode = "NULLABLE" },
    { name = "saldo_despues", type = "FLOAT64", mode = "NULLABLE" },
    { name = "canal", type = "STRING", mode = "NULLABLE" },
    { name = "ingestion_timestamp", type = "TIMESTAMP", mode = "REQUIRED" },
    { name = "source_system", type = "STRING", mode = "NULLABLE" }
  ])
}

# Tabla RDV: clientes_raw
resource "google_bigquery_table" "clientes_raw" {
  dataset_id = google_bigquery_dataset.banking_rdv.dataset_id
  table_id   = "clientes_raw"
  
  clustering = ["segmento_cliente", "ciudad"]
  
  schema = jsonencode([
    { name = "id_cliente", type = "STRING", mode = "REQUIRED" },
    { name = "nombre_completo", type = "STRING", mode = "NULLABLE" },
    { name = "fecha_nacimiento", type = "STRING", mode = "NULLABLE" },
    { name = "genero", type = "STRING", mode = "NULLABLE" },
    { name = "ciudad", type = "STRING", mode = "NULLABLE" },
    { name = "segmento_cliente", type = "STRING", mode = "NULLABLE" },
    { name = "fecha_alta_cliente", type = "STRING", mode = "NULLABLE" },
    { name = "ingestion_timestamp", type = "TIMESTAMP", mode = "REQUIRED" }
  ])
}
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/bigquery.tf"

# terraform/cloud_functions.tf
cat > terraform/cloud_functions.tf << 'EOF'
# Bucket para Cloud Functions
resource "google_storage_bucket" "functions_bucket" {
  name          = "${var.project_id}-functions-${var.taller_prefix}"
  location      = var.region
  force_destroy = true
  
  uniform_bucket_level_access = true
}

# Service Account
resource "google_service_account" "function_sa" {
  account_id   = "${var.taller_prefix}-cf-sa"
  display_name = "Cloud Functions SA - Taller Banking"
}

# IAM Roles
resource "google_project_iam_member" "function_sa_roles" {
  for_each = toset([
    "roles/cloudsql.client",
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser"
  ])
  
  project = var.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

# Cloud Function source (placeholder)
resource "google_storage_bucket_object" "sql_to_bq_source" {
  name   = "functions/sql_to_bq.zip"
  bucket = google_storage_bucket.functions_bucket.name
  source = "${path.module}/../cloud_functions/sql_to_bq.zip"
}

# Cloud Function
resource "google_cloudfunctions2_function" "sql_to_bq" {
  name        = "${var.taller_prefix}-sql-to-bq"
  location    = var.region
  description = "ETL: SQL Server → BigQuery RDV"
  
  build_config {
    runtime     = "python311"
    entry_point = "sync_sql_to_bq"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_bucket.name
        object = google_storage_bucket_object.sql_to_bq_source.name
      }
    }
  }
  
  service_config {
    max_instance_count    = 10
    available_memory      = "512M"
    timeout_seconds       = 540
    service_account_email = google_service_account.function_sa.email
    
    environment_variables = {
      PROJECT_ID           = var.project_id
      SQL_INSTANCE_NAME    = google_sql_database_instance.taller_sqlserver.connection_name
      SQL_DATABASE         = google_sql_database.banking_taller.name
      SQL_USER             = google_sql_user.sqlserver_user.name
      BIGQUERY_DATASET_RDV = google_bigquery_dataset.banking_rdv.dataset_id
    }
    
    secret_environment_variables {
      key        = "SQL_PASSWORD"
      project_id = var.project_id
      secret     = google_secret_manager_secret.sql_password.secret_id
      version    = "latest"
    }
  }
}

# Cloud Scheduler
resource "google_cloud_scheduler_job" "sql_to_bq_sync" {
  name        = "${var.taller_prefix}-sync"
  description = "Sync SQL → BQ cada hora"
  schedule    = "0 * * * *"
  time_zone   = "America/Lima"
  
  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.sql_to_bq.service_config[0].uri
    
    oidc_token {
      service_account_email = google_service_account.function_sa.email
    }
  }
}
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/cloud_functions.tf"

# terraform/iam.tf
cat > terraform/iam.tf << 'EOF'
# Secret Manager
resource "google_secret_manager_secret" "sql_password" {
  secret_id = "${var.taller_prefix}-sql-password"
  
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "sql_password_version" {
  secret      = google_secret_manager_secret.sql_password.id
  secret_data = var.sql_password
}

# IAM para Cloud Function
resource "google_secret_manager_secret_iam_member" "function_secret_accessor" {
  secret_id = google_secret_manager_secret.sql_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.function_sa.email}"
}

# IAM para participantes (BigQuery viewer)
resource "google_bigquery_dataset_iam_member" "participants_ddv_viewer" {
  dataset_id = google_bigquery_dataset.banking_ddv.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "allAuthenticatedUsers"  # Cambiar por grupo específico
}
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/iam.tf"

# terraform/outputs.tf
cat > terraform/outputs.tf << 'EOF'
output "sql_server_connection" {
  description = "Cloud SQL Server connection details"
  value = {
    host     = google_sql_database_instance.taller_sqlserver.public_ip_address
    port     = 1433
    database = google_sql_database.banking_taller.name
    user     = google_sql_user.sqlserver_user.name
  }
}

output "sql_connection_string" {
  description = "Connection string para scripts Python"
  value       = "Server=${google_sql_database_instance.taller_sqlserver.public_ip_address},1433;Database=${google_sql_database.banking_taller.name};User Id=${google_sql_user.sqlserver_user.name};Password=***;"
  sensitive   = true
}

output "bigquery_datasets" {
  description = "BigQuery datasets creados"
  value = {
    rdv = google_bigquery_dataset.banking_rdv.dataset_id
    udv = google_bigquery_dataset.banking_udv.dataset_id
    ddv = google_bigquery_dataset.banking_ddv.dataset_id
  }
}

output "cloud_function_url" {
  description = "URL de Cloud Function"
  value       = google_cloudfunctions2_function.sql_to_bq.service_config[0].uri
}

output "participantes_instructions" {
  description = "Instrucciones para compartir con participantes"
  value = <<-EOT
    TALLER BANKING - CREDENCIALES
    
    SQL Server:
    - Host: ${google_sql_database_instance.taller_sqlserver.public_ip_address}
    - Port: 1433
    - Database: ${google_sql_database.banking_taller.name}
    - User: ${google_sql_user.sqlserver_user.name}
    - Password: [PROPORCIONADO SEPARADAMENTE]
    
    BigQuery:
    - Project: ${var.project_id}
    - RDV: ${google_bigquery_dataset.banking_rdv.dataset_id}
    - UDV: ${google_bigquery_dataset.banking_udv.dataset_id}
    - DDV: ${google_bigquery_dataset.banking_ddv.dataset_id}
  EOT
}
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/outputs.tf"

# terraform/terraform.tfvars.example
cat > terraform/terraform.tfvars.example << 'EOF'
# =============================================================================
# TALLER BANKING - TERRAFORM VARIABLES
# =============================================================================
# Copiar este archivo a terraform.tfvars y completar con valores reales

project_id         = "tu-proyecto-gcp"
region             = "us-east4"
taller_prefix      = "taller-banking"
sql_password       = "TallerBanking2024!"
participants_count = 35
sql_tier           = "db-custom-2-7680"  # 2 vCPU, 7.6GB RAM

# Cambiar a true en producción
enable_deletion_protection = false
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/terraform.tfvars.example"

# =============================================================================
# 3. SQL QUERIES
# =============================================================================

echo ""
echo "📝 Generando queries SQL..."
echo ""

# terraform/sql/udv_transacciones_clean.sql
cat > terraform/sql/udv_transacciones_clean.sql << 'EOF'
-- UDV: Transacciones Clean
CREATE OR REPLACE TABLE `${project_id}.${udv_dataset}.transacciones_clean`
PARTITION BY fecha_transaccion
CLUSTER BY id_cliente, tipo_transaccion
AS
SELECT
    UPPER(TRIM(id_cliente)) AS id_cliente,
    
    CASE
        WHEN fecha_transaccion = '0000-00-00' THEN NULL
        WHEN SAFE.PARSE_DATE('%Y-%m-%d', fecha_transaccion) IS NULL THEN NULL
        WHEN SAFE.PARSE_DATE('%Y-%m-%d', fecha_transaccion) > CURRENT_DATE() THEN NULL
        ELSE SAFE.PARSE_DATE('%Y-%m-%d', fecha_transaccion)
    END AS fecha_transaccion,
    
    CASE
        WHEN LOWER(TRIM(tipo_transaccion)) IN ('pago', 'payment') THEN 'PAGO'
        WHEN LOWER(TRIM(tipo_transaccion)) IN ('deposito', 'dep', 'depósito') THEN 'DEPOSITO'
        WHEN LOWER(TRIM(tipo_transaccion)) IN ('retiro', 'ret') THEN 'RETIRO'
        WHEN LOWER(TRIM(tipo_transaccion)) IN ('transferencia', 'trans') THEN 'TRANSFERENCIA'
        ELSE 'OTRO'
    END AS tipo_transaccion,
    
    ROUND(monto, 2) AS monto,
    ROUND(saldo_despues, 2) AS saldo_despues,
    
    CASE
        WHEN LOWER(TRIM(canal)) LIKE '%app%movil%' THEN 'APP_MOVIL'
        WHEN LOWER(TRIM(canal)) LIKE '%web%' THEN 'WEB'
        WHEN LOWER(TRIM(canal)) LIKE '%cajero%' THEN 'CAJERO'
        WHEN LOWER(TRIM(canal)) IN ('sucursal', 'branch') THEN 'SUCURSAL'
        ELSE 'DESCONOCIDO'
    END AS canal,
    
    ingestion_timestamp,
    source_system
FROM `${project_id}.${rdv_dataset}.transacciones_raw`
WHERE id_cliente IS NOT NULL;
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/sql/udv_transacciones_clean.sql"

# terraform/sql/udv_clientes_clean.sql
cat > terraform/sql/udv_clientes_clean.sql << 'EOF'
-- UDV: Clientes Clean
CREATE OR REPLACE TABLE `${project_id}.${udv_dataset}.clientes_clean`
CLUSTER BY segmento_cliente, ciudad
AS
SELECT
    UPPER(TRIM(id_cliente)) AS id_cliente,
    
    CASE
        WHEN LOWER(nombre_completo) IN ('test', 'asdasd', 'xxxxxx', 'null') THEN NULL
        ELSE TRIM(REGEXP_REPLACE(nombre_completo, r'\s+', ' '))
    END AS nombre_completo,
    
    CASE
        WHEN fecha_nacimiento = '0000-00-00' THEN NULL
        WHEN SAFE.PARSE_DATE('%Y-%m-%d', fecha_nacimiento) > CURRENT_DATE() THEN NULL
        ELSE SAFE.PARSE_DATE('%Y-%m-%d', fecha_nacimiento)
    END AS fecha_nacimiento,
    
    CASE
        WHEN UPPER(genero) IN ('M', 'MASCULINO') THEN 'M'
        WHEN UPPER(genero) IN ('F', 'FEMENINO') THEN 'F'
        ELSE NULL
    END AS genero,
    
    INITCAP(TRIM(ciudad)) AS ciudad,
    
    CASE
        WHEN LOWER(segmento_cliente) IN ('premium', 'vip', 'gold') THEN 'PREMIUM'
        WHEN LOWER(segmento_cliente) IN ('estándar', 'estandar', 'basico') THEN 'ESTANDAR'
        WHEN LOWER(segmento_cliente) = 'joven' THEN 'JOVEN'
        ELSE 'DESCONOCIDO'
    END AS segmento_cliente,
    
    SAFE.PARSE_DATE('%Y-%m-%d', fecha_alta_cliente) AS fecha_alta_cliente,
    DATE_DIFF(CURRENT_DATE(), SAFE.PARSE_DATE('%Y-%m-%d', fecha_nacimiento), YEAR) AS edad,
    ingestion_timestamp
FROM `${project_id}.${rdv_dataset}.clientes_raw`
WHERE id_cliente IS NOT NULL;
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/sql/udv_clientes_clean.sql"

# terraform/sql/ddv_kpi_transaccional.sql
cat > terraform/sql/ddv_kpi_transaccional.sql << 'EOF'
-- DDV: KPI Transaccional Diario
CREATE OR REPLACE TABLE `${project_id}.${ddv_dataset}.kpi_transaccional_diario`
PARTITION BY fecha
AS
SELECT
    fecha_transaccion AS fecha,
    tipo_transaccion,
    canal,
    
    COUNT(*) AS total_transacciones,
    COUNT(DISTINCT id_cliente) AS clientes_activos,
    
    SUM(monto) AS monto_total,
    AVG(monto) AS monto_promedio,
    APPROX_QUANTILES(monto, 100)[OFFSET(50)] AS monto_mediana,
    MAX(monto) AS monto_maximo,
    MIN(monto) AS monto_minimo,
    
    CURRENT_TIMESTAMP() AS ultima_actualizacion
FROM `${project_id}.${udv_dataset}.transacciones_clean`
GROUP BY fecha, tipo_transaccion, canal;
EOF

echo -e "${GREEN}✓${NC} Generado: terraform/sql/ddv_kpi_transaccional.sql"

# =============================================================================
# 4. CLOUD FUNCTIONS
# =============================================================================

echo ""
echo "📝 Generando Cloud Functions..."
echo ""

# cloud_functions/sql_to_bq/main.py
cat > cloud_functions/sql_to_bq/main.py << 'EOF'
"""
Cloud Function: SQL Server → BigQuery RDV
Sync automático cada hora
"""
import pymssql
import os
from google.cloud import bigquery
from datetime import datetime
import functions_framework

PROJECT_ID = os.environ['PROJECT_ID']
SQL_INSTANCE = os.environ['SQL_INSTANCE_NAME']
SQL_DATABASE = os.environ['SQL_DATABASE']
SQL_USER = os.environ['SQL_USER']
SQL_PASSWORD = os.environ['SQL_PASSWORD']
BQ_DATASET = os.environ['BIGQUERY_DATASET_RDV']

def get_sql_connection():
    """Conectar a Cloud SQL Server"""
    # Extraer host de connection_name: project:region:instance
    parts = SQL_INSTANCE.split(':')
    host = f"/cloudsql/{SQL_INSTANCE}"
    
    conn = pymssql.connect(
        server=host,
        user=SQL_USER,
        password=SQL_PASSWORD,
        database=SQL_DATABASE
    )
    return conn

def sync_table(sql_conn, bq_client, sql_table, bq_table, columns):
    """Sincronizar tabla SQL → BigQuery"""
    cursor = sql_conn.cursor(as_dict=True)
    
    # Query SQL Server
    cols_str = ', '.join(columns)
    query = f"""
        SELECT 
            {cols_str},
            GETDATE() as ingestion_timestamp,
            'SQL_SERVER' as source_system
        FROM {sql_table}
    """
    cursor.execute(query)
    rows = cursor.fetchall()
    
    if not rows:
        print(f"⚠️ No data in {sql_table}")
        return 0
    
    # Insert to BigQuery
    table_ref = f"{PROJECT_ID}.{BQ_DATASET}.{bq_table}"
    
    job_config = bigquery.LoadJobConfig(
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
        schema_update_options=[
            bigquery.SchemaUpdateOption.ALLOW_FIELD_ADDITION
        ]
    )
    
    job = bq_client.load_table_from_json(
        rows,
        table_ref,
        job_config=job_config
    )
    job.result()
    
    print(f"✅ Synced {len(rows)} rows: {sql_table} → {bq_table}")
    return len(rows)

@functions_framework.http
def sync_sql_to_bq(request):
    """Entry point"""
    print("🚀 Starting SQL Server → BigQuery sync")
    
    try:
        sql_conn = get_sql_connection()
        bq_client = bigquery.Client(project=PROJECT_ID)
        
        # Sync transacciones
        trans_count = sync_table(
            sql_conn, 
            bq_client,
            'transacciones_raw',
            'transacciones_raw',
            ['id_cliente', 'fecha_transaccion', 'tipo_transaccion', 
             'monto', 'saldo_despues', 'canal']
        )
        
        # Sync clientes
        clientes_count = sync_table(
            sql_conn,
            bq_client,
            'clientes_raw',
            'clientes_raw',
            ['id_cliente', 'nombre_completo', 'fecha_nacimiento',
             'genero', 'ciudad', 'segmento_cliente', 'fecha_alta_cliente']
        )
        
        sql_conn.close()
        
        return {
            'status': 'success',
            'timestamp': datetime.utcnow().isoformat(),
            'transacciones': trans_count,
            'clientes': clientes_count
        }, 200
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return {'status': 'error', 'message': str(e)}, 500
EOF

echo -e "${GREEN}✓${NC} Generado: cloud_functions/sql_to_bq/main.py"

# cloud_functions/sql_to_bq/requirements.txt
cat > cloud_functions/sql_to_bq/requirements.txt << 'EOF'
functions-framework==3.5.0
google-cloud-bigquery==3.14.0
pymssql==2.2.11
EOF

echo -e "${GREEN}✓${NC} Generado: cloud_functions/sql_to_bq/requirements.txt"

# =============================================================================
# 5. PYTHON SCRIPTS
# =============================================================================

echo ""
echo "📝 Generando scripts Python..."
echo ""

# scripts/load_csv_to_sqlserver.py
cat > scripts/load_csv_to_sqlserver.py << 'EOF'
"""
Script: Cargar CSVs a Cloud SQL Server
Para taller de 35 personas
"""
import pandas as pd
import pymssql
import os
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv('DB_HOST')
DB_PORT = int(os.getenv('DB_PORT', '1433'))
DB_NAME = os.getenv('DB_NAME', 'banking_taller')
DB_USER = os.getenv('DB_USER', 'sqlserver')
DB_PASS = os.getenv('DB_PASS')

def create_connection():
    """Conectar a SQL Server"""
    try:
        conn = pymssql.connect(
            server=DB_HOST,
            port=DB_PORT,
            user=DB_USER,
            password=DB_PASS,
            database=DB_NAME
        )
        print(f"✅ Conectado: {DB_HOST}")
        return conn
    except Exception as e:
        print(f"❌ Error: {e}")
        raise

def create_tables(conn):
    """Crear tablas"""
    cursor = conn.cursor()
    
    cursor.execute("""
    IF OBJECT_ID('transacciones_raw', 'U') IS NOT NULL 
        DROP TABLE transacciones_raw;
    
    CREATE TABLE transacciones_raw (
        id INT IDENTITY(1,1) PRIMARY KEY,
        id_cliente VARCHAR(50),
        fecha_transaccion VARCHAR(50),
        tipo_transaccion VARCHAR(100),
        monto DECIMAL(18,2),
        saldo_despues DECIMAL(18,2),
        canal VARCHAR(100),
        ingestion_timestamp DATETIME DEFAULT GETDATE()
    );
    """)
    
    cursor.execute("""
    IF OBJECT_ID('clientes_raw', 'U') IS NOT NULL 
        DROP TABLE clientes_raw;
    
    CREATE TABLE clientes_raw (
        id INT IDENTITY(1,1) PRIMARY KEY,
        id_cliente VARCHAR(50),
        nombre_completo VARCHAR(255),
        fecha_nacimiento VARCHAR(50),
        genero VARCHAR(10),
        ciudad VARCHAR(100),
        segmento_cliente VARCHAR(50),
        fecha_alta_cliente VARCHAR(50),
        ingestion_timestamp DATETIME DEFAULT GETDATE()
    );
    """)
    
    conn.commit()
    print("✅ Tablas creadas")

def load_csv(conn, csv_file, table_name, columns):
    """Cargar CSV"""
    cursor = conn.cursor()
    df = pd.read_csv(csv_file)
    
    print(f"📊 Cargando {len(df)} registros: {csv_file}")
    
    placeholders = ','.join(['%s'] * len(columns))
    query = f"INSERT INTO {table_name} ({','.join(columns)}) VALUES ({placeholders})"
    
    batch_size = 1000
    for i in range(0, len(df), batch_size):
        batch = df.iloc[i:i+batch_size]
        rows = [tuple(row) for row in batch[columns].values]
        cursor.executemany(query, rows)
        conn.commit()
        print(f"  ⏳ {i+len(rows)}/{len(df)}")
    
    print(f"✅ Completado: {table_name}")

def main():
    print("\n" + "="*60)
    print("🚀 CARGA CSVs → SQL SERVER")
    print("="*60 + "\n")
    
    if not DB_PASS:
        print("❌ Variable DB_PASS no definida")
        return
    
    conn = create_connection()
    create_tables(conn)
    
    load_csv(
        conn,
        'data/clientes_transacciones.csv',
        'transacciones_raw',
        ['id_cliente', 'fecha_transaccion', 'tipo_transaccion',
         'monto', 'saldo_despues', 'canal']
    )
    
    load_csv(
        conn,
        'data/maestra_clientes.csv',
        'clientes_raw',
        ['id_cliente', 'nombre_completo', 'fecha_nacimiento',
         'genero', 'ciudad', 'segmento_cliente', 'fecha_alta_cliente']
    )
    
    print("\n" + "="*60)
    print("✅ CARGA COMPLETADA")
    print("="*60 + "\n")
    
    conn.close()

if __name__ == "__main__":
    main()
EOF

echo -e "${GREEN}✓${NC} Generado: scripts/load_csv_to_sqlserver.py"

# scripts/test_connection.py
cat > scripts/test_connection.py << 'EOF'
"""
Test: Conexión a Cloud SQL Server
"""
import pymssql
import os
from dotenv import load_dotenv

load_dotenv()

def test_connection():
    try:
        conn = pymssql.connect(
            server=os.getenv('DB_HOST'),
            port=int(os.getenv('DB_PORT', '1433')),
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'),
            database=os.getenv('DB_NAME')
        )
        
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        version = cursor.fetchone()
        
        print("✅ Conexión exitosa!")
        print(f"📊 SQL Server: {version[0][:50]}...")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    test_connection()
EOF

echo -e "${GREEN}✓${NC} Generado: scripts/test_connection.py"

# scripts/requirements.txt
cat > scripts/requirements.txt << 'EOF'
pandas==2.1.4
pymssql==2.2.11
python-dotenv==1.0.0
EOF

echo -e "${GREEN}✓${NC} Generado: scripts/requirements.txt"

# =============================================================================
# 6. DATA DIRECTORY
# =============================================================================

touch data/.gitkeep
echo -e "${GREEN}✓${NC} Generado: data/.gitkeep"

# =============================================================================
# FINAL
# =============================================================================

echo ""
echo "=================================================="
echo "✅ ESTRUCTURA GENERADA EXITOSAMENTE"
echo "=================================================="
echo ""
echo "📂 Estructura creada en: $(pwd)"
echo ""
echo "🚀 PRÓXIMOS PASOS:"
echo ""
echo "1. Copiar CSVs a data/"
echo "   cp clientes_transacciones.csv data/"
echo "   cp maestra_clientes.csv data/"
echo ""
echo "2. Configurar variables:"
echo "   cp .env.example .env"
echo "   # Editar .env con tus valores"
echo ""
echo "3. Empaquetar Cloud Function:"
echo "   cd cloud_functions/sql_to_bq"
echo "   zip -r ../sql_to_bq.zip main.py requirements.txt"
echo "   cd ../.."
echo ""
echo "4. Desplegar Terraform:"
echo "   cd terraform"
echo "   cp terraform.tfvars.example terraform.tfvars"
echo "   # Editar terraform.tfvars"
echo "   terraform init"
echo "   terraform plan"
echo "   terraform apply"
echo ""
echo "5. Cargar datos:"
echo "   pip install -r scripts/requirements.txt"
echo "   python scripts/load_csv_to_sqlserver.py"
echo ""
echo "=================================================="

# Crear archivo de instrucciones
cat > SETUP_INSTRUCTIONS.md << 'EOF'
# 📝 INSTRUCCIONES DE SETUP

## 1. Preparar CSVs
```bash
cp /ruta/clientes_transacciones.csv data/
cp /ruta/maestra_clientes.csv data/
```

## 2. Configurar Variables
```bash
cp .env.example .env
nano .env  # Completar con valores reales
```

## 3. Empaquetar Cloud Function
```bash
cd cloud_functions/sql_to_bq
zip -r ../sql_to_bq.zip main.py requirements.txt
cd ../..
```

## 4. Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Completar con valores reales

terraform init
terraform plan
terraform apply
```

## 5. Cargar Datos
```bash
pip install -r scripts/requirements.txt
python scripts/load_csv_to_sqlserver.py
```

## 6. Verificar
```bash
python scripts/test_connection.py
```

## 7. Trigger Sync Manual
```bash
FUNCTION_URL=$(cd terraform && terraform output -raw cloud_function_url)
curl -X POST $FUNCTION_URL \
  -H "Authorization: Bearer $(gcloud auth print-identity-token)"
```
EOF

echo -e "${GREEN}✓${NC} Generado: SETUP_INSTRUCTIONS.md"

echo ""
echo "📖 Ver SETUP_INSTRUCTIONS.md para guía detallada"
echo ""

