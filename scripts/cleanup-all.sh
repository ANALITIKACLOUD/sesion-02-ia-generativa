#!/bin/bash
# Script para limpiar infraestructura de todos los estudiantes

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Cleanup de Infraestructura${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Verificar que estamos en la carpeta correcta
if [ ! -d "student" ]; then
    echo -e "${RED}Error: Este script debe ejecutarse desde la raíz del proyecto${NC}"
    exit 1
fi

# Listar estudiantes activos
if [ ! -f "shared-outputs.json" ]; then
    echo -e "${RED}Error: No se encontró shared-outputs.json${NC}"
    exit 1
fi

BUCKET=$(jq -r '.terraform_state_bucket.value' shared-outputs.json)
echo -e "${GREEN}Buscando estados de Terraform en: $BUCKET${NC}"
echo ""

# Listar todos los estados
aws s3 ls s3://$BUCKET/students/ --recursive | grep tfstate | awk '{print $4}' | while read state_file; do
    STUDENT_ID=$(echo $state_file | cut -d'/' -f2)
    echo -e "${YELLOW}Encontrado: $STUDENT_ID${NC}"
done

echo ""
echo -e "${RED}⚠ ADVERTENCIA: Esto destruirá TODA la infraestructura de estudiantes${NC}"
echo -e "${YELLOW}¿Continuar? (escribir 'yes' para confirmar):${NC}"
read -p "" response

if [ "$response" != "yes" ]; then
    echo "Operación cancelada"
    exit 0
fi

# Cleanup por cada estudiante
aws s3 ls s3://$BUCKET/students/ --recursive | grep tfstate | awk '{print $4}' | while read state_file; do
    STUDENT_ID=$(echo $state_file | cut -d'/' -f2)
    
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Limpiando: $STUDENT_ID${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    cd student
    
    # Configurar student_id temporal
    export TF_VAR_student_id=$STUDENT_ID
    
    # Destroy
    terraform destroy -auto-approve || echo -e "${RED}Error al destruir $STUDENT_ID${NC}"
    
    cd ..
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Cleanup completado${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Nota: La infraestructura compartida (shared/) NO fue eliminada${NC}"
echo -e "${YELLOW}Para eliminarla, ejecutar manualmente:${NC}"
echo -e "  cd shared && terraform destroy"
echo ""
