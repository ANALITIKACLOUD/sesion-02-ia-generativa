#!/bin/bash
# Pre-flight checklist para instructor antes del taller

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Taller RAG - Pre-flight Checklist${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

ERRORS=0
WARNINGS=0

# 1. Verificar herramientas instaladas
echo -e "${YELLOW}[1/8] Verificando herramientas...${NC}"

if command -v aws &> /dev/null; then
    echo -e "${GREEN}✓ AWS CLI instalado ($(aws --version | cut -d' ' -f1))${NC}"
else
    echo -e "${RED}✗ AWS CLI no instalado${NC}"
    ((ERRORS++))
fi

if command -v terraform &> /dev/null; then
    echo -e "${GREEN}✓ Terraform instalado ($(terraform version | head -n1))${NC}"
else
    echo -e "${RED}✗ Terraform no instalado${NC}"
    ((ERRORS++))
fi

if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq instalado${NC}"
else
    echo -e "${YELLOW}⚠ jq no instalado (recomendado)${NC}"
    ((WARNINGS++))
fi

echo ""

# 2. Verificar credenciales AWS
echo -e "${YELLOW}[2/8] Verificando credenciales AWS...${NC}"

if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    echo -e "${GREEN}✓ Credenciales válidas${NC}"
    echo -e "  Account: ${ACCOUNT_ID}"
    echo -e "  User: ${USER_ARN}"
else
    echo -e "${RED}✗ Credenciales AWS no configuradas${NC}"
    ((ERRORS++))
fi

echo ""

# 3. Verificar región
echo -e "${YELLOW}[3/8] Verificando región AWS...${NC}"

REGION=${AWS_REGION:-us-east-1}
echo -e "${GREEN}✓ Región configurada: ${REGION}${NC}"

# Verificar que Bedrock está disponible en la región
if aws bedrock list-foundation-models --region ${REGION} &> /dev/null; then
    echo -e "${GREEN}✓ Bedrock disponible en ${REGION}${NC}"
    
    # Verificar modelo Titan Embeddings
    if aws bedrock list-foundation-models --region ${REGION} \
        --query 'modelSummaries[?contains(modelId, `titan-embed-text-v1`)]' \
        --output text | grep -q "titan"; then
        echo -e "${GREEN}✓ Titan Embeddings disponible${NC}"
    else
        echo -e "${RED}✗ Titan Embeddings no disponible${NC}"
        echo -e "  Habilita el modelo en la consola de Bedrock"
        ((ERRORS++))
    fi
else
    echo -e "${RED}✗ Bedrock no disponible en ${REGION}${NC}"
    echo -e "  Considera usar us-east-1 o us-west-2"
    ((ERRORS++))
fi

echo ""

# 4. Verificar Service Quotas
echo -e "${YELLOW}[4/8] Verificando Service Quotas...${NC}"

# VPC Endpoints
VPC_ENDPOINTS=$(aws service-quotas get-service-quota \
    --service-code vpc \
    --quota-code L-45FE3B85 \
    --query 'Quota.Value' \
    --output text 2>/dev/null || echo "N/A")

if [ "$VPC_ENDPOINTS" != "N/A" ]; then
    echo -e "${GREEN}✓ VPC Endpoints limit: ${VPC_ENDPOINTS}${NC}"
    if (( $(echo "$VPC_ENDPOINTS < 10" | bc -l) )); then
        echo -e "${YELLOW}  ⚠ Considera solicitar aumento (necesitas 3)${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ No se pudo verificar límite de VPC Endpoints${NC}"
    ((WARNINGS++))
fi

# Lambda Concurrent Executions
LAMBDA_CONCURRENT=$(aws service-quotas get-service-quota \
    --service-code lambda \
    --quota-code L-B99A9384 \
    --query 'Quota.Value' \
    --output text 2>/dev/null || echo "N/A")

if [ "$LAMBDA_CONCURRENT" != "N/A" ]; then
    echo -e "${GREEN}✓ Lambda Concurrent Executions: ${LAMBDA_CONCURRENT}${NC}"
    if (( $(echo "$LAMBDA_CONCURRENT < 100" | bc -l) )); then
        echo -e "${YELLOW}  ⚠ Considera solicitar aumento (35+ estudiantes)${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ No se pudo verificar límite de Lambda${NC}"
    ((WARNINGS++))
fi

echo ""

# 5. Verificar estructura del proyecto
echo -e "${YELLOW}[5/8] Verificando estructura del proyecto...${NC}"

REQUIRED_DIRS=("shared" "student" "lambda" "scripts")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓ Directorio ${dir}/ existe${NC}"
    else
        echo -e "${RED}✗ Directorio ${dir}/ no encontrado${NC}"
        ((ERRORS++))
    fi
done

echo ""

# 6. Verificar archivos críticos
echo -e "${YELLOW}[6/8] Verificando archivos críticos...${NC}"

CRITICAL_FILES=(
    "shared/backend.tf"
    "shared/vpc.tf"
    "shared/opensearch.tf"
    "student/backend.tf"
    "student/lambda.tf"
    "lambda/index.py"
    "lambda/requirements.txt"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ ${file}${NC}"
    else
        echo -e "${RED}✗ ${file} no encontrado${NC}"
        ((ERRORS++))
    fi
done

echo ""

# 7. Validar Terraform
echo -e "${YELLOW}[7/8] Validando configuración Terraform...${NC}"

cd shared 2>/dev/null || { echo -e "${RED}✗ No se puede acceder a shared/${NC}"; ((ERRORS++)); }

if [ -d ".terraform" ] || terraform init -backend=false &> /dev/null; then
    if terraform validate &> /dev/null; then
        echo -e "${GREEN}✓ Configuración shared válida${NC}"
    else
        echo -e "${RED}✗ Errores en configuración shared${NC}"
        terraform validate
        ((ERRORS++))
    fi
else
    echo -e "${YELLOW}⚠ No se pudo inicializar Terraform en shared/${NC}"
    ((WARNINGS++))
fi

cd ..

echo ""

# 8. Verificar infraestructura desplegada (si existe)
echo -e "${YELLOW}[8/8] Verificando infraestructura existente...${NC}"

# Verificar si el bucket de terraform state existe
STATE_BUCKET="taller-rag-terraform-state"
if aws s3 ls "s3://${STATE_BUCKET}" &> /dev/null 2>&1; then
    echo -e "${GREEN}✓ Bucket de Terraform state existe: ${STATE_BUCKET}${NC}"
    
    # Verificar si hay infraestructura shared desplegada
    if aws s3 ls "s3://${STATE_BUCKET}/terraform.tfstate" &> /dev/null 2>&1; then
        echo -e "${GREEN}✓ Infraestructura shared ya desplegada${NC}"
    else
        echo -e "${YELLOW}⚠ Infraestructura shared no desplegada aún${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Bucket de Terraform state no existe (se creará al desplegar)${NC}"
fi

# Verificar VPC
VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Project,Values=TallerRAG" --query 'Vpcs[*].VpcId' --output text)
if [ -n "$VPCS" ]; then
    echo -e "${GREEN}✓ VPC del taller encontrada: ${VPCS}${NC}"
else
    echo -e "${YELLOW}⚠ VPC no encontrada (se creará al desplegar)${NC}"
fi

echo ""

# Resumen final
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Resumen${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ No hay errores críticos${NC}"
else
    echo -e "${RED}✗ ${ERRORS} error(es) encontrado(s)${NC}"
fi

if [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ No hay advertencias${NC}"
else
    echo -e "${YELLOW}⚠ ${WARNINGS} advertencia(s)${NC}"
fi

echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}   ¡Listo para el taller!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo -e "Próximos pasos:"
    echo -e "  1. ${YELLOW}cd shared/ && terraform init && terraform apply${NC}"
    echo -e "  2. ${YELLOW}terraform output -json > ../shared-outputs.json${NC}"
    echo -e "  3. Distribuir shared-outputs.json a estudiantes"
    echo ""
else
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}   Corrige los errores antes del taller${NC}"
    echo -e "${RED}=========================================${NC}"
    exit 1
fi
