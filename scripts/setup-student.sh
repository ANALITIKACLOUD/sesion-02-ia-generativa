#!/bin/bash
# Script para setup inicial del estudiante

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Taller RAG - Setup de Estudiante${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Verificar que estamos en la carpeta correcta
if [ ! -d "student" ]; then
    echo -e "${RED}Error: Este script debe ejecutarse desde la raíz del proyecto${NC}"
    exit 1
fi

# Solicitar STUDENT_ID
echo -e "${YELLOW}Ingresa tu ID de estudiante (formato: alumnoXX):${NC}"
read -p "STUDENT_ID: " STUDENT_ID

# Validar formato
if ! [[ $STUDENT_ID =~ ^alumno[0-9]{2}$ ]]; then
    echo -e "${RED}Error: El formato debe ser alumnoXX donde XX son dos dígitos${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ID válido: $STUDENT_ID${NC}"
echo ""

# Verificar que existe shared-outputs.json
if [ ! -f "shared-outputs.json" ]; then
    echo -e "${RED}Error: No se encontró shared-outputs.json${NC}"
    echo -e "${YELLOW}El instructor debe proporcionar este archivo primero${NC}"
    exit 1
fi

echo -e "${GREEN}✓ shared-outputs.json encontrado${NC}"

# Construir Lambda con dependencias si no está construido
echo ""
echo -e "${YELLOW}Verificando dependencias Lambda...${NC}"
if [ ! -d "../lambda/opensearchpy" ]; then
    echo -e "${YELLOW}Construyendo Lambda con dependencias...${NC}"
    cd ../lambda
    if [ -f "build.sh" ]; then
        chmod +x build.sh
        ./build.sh
    else
        echo -e "${YELLOW}Instalando dependencias manualmente...${NC}"
        pip3 install -r requirements.txt -t . --upgrade
    fi
    cd ../student
    echo -e "${GREEN}✓ Dependencias instaladas${NC}"
else
    echo -e "${GREEN}✓ Dependencias ya instaladas${NC}"
fi

# Crear terraform.tfvars desde el template
cd student
if [ -f "terraform.tfvars" ]; then
    echo -e "${YELLOW}⚠ terraform.tfvars ya existe. ¿Sobreescribir? (y/N)${NC}"
    read -p "" response
    if [[ ! $response =~ ^[Yy]$ ]]; then
        echo "Operación cancelada"
        exit 0
    fi
fi

# Extraer valores de shared-outputs.json
VPC_ID=$(jq -r '.vpc_id.value' ../shared-outputs.json)
SUBNET_IDS=$(jq -r '.private_subnet_ids.value | @json' ../shared-outputs.json)
LAMBDA_SG=$(jq -r '.lambda_security_group_id.value' ../shared-outputs.json)
OS_ENDPOINT=$(jq -r '.opensearch_endpoint.value' ../shared-outputs.json)
OS_ARN=$(jq -r '.opensearch_domain_arn.value' ../shared-outputs.json)
REGION=$(jq -r '.aws_region.value' ../shared-outputs.json)

# Crear terraform.tfvars
cat > terraform.tfvars <<EOF
# ============================================
# CONFIGURACIÓN DEL ESTUDIANTE
# ============================================
# Generado automáticamente por setup-student.sh

student_id = "$STUDENT_ID"

# ============================================
# CONFIGURACIÓN DE INFRAESTRUCTURA COMPARTIDA
# ============================================

aws_region = "$REGION"
vpc_id = "$VPC_ID"
private_subnet_ids = $SUBNET_IDS
lambda_security_group_id = "$LAMBDA_SG"
opensearch_endpoint = "$OS_ENDPOINT"
opensearch_domain_arn = "$OS_ARN"
EOF

echo -e "${GREEN}✓ terraform.tfvars creado${NC}"
echo ""

# Inicializar Terraform
echo -e "${YELLOW}Inicializando Terraform...${NC}"
terraform init -backend-config="key=students/${STUDENT_ID}/terraform.tfstate"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Setup completado exitosamente!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Siguiente paso: ${YELLOW}terraform apply${NC}"
echo ""
