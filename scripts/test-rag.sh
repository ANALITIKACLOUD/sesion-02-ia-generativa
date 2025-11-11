#!/bin/bash
# Script para probar el pipeline RAG de un estudiante

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función de ayuda
usage() {
    echo "Uso: $0 <student_id>"
    echo ""
    echo "Ejemplo: $0 alumno01"
    exit 1
}

# Verificar argumentos
if [ -z "$1" ]; then
    usage
fi

STUDENT_ID=$1
BUCKET="rag-${STUDENT_ID}"
FUNCTION_NAME="rag-lambda-${STUDENT_ID}"
INDEX_NAME="rag-${STUDENT_ID}"

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}   Testing RAG Pipeline: ${STUDENT_ID}${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# 1. Verificar que la infraestructura existe
echo -e "${YELLOW}[1/6] Verificando infraestructura...${NC}"

# Verificar bucket
if aws s3 ls "s3://${BUCKET}" &> /dev/null; then
    echo -e "${GREEN}✓ Bucket encontrado: ${BUCKET}${NC}"
else
    echo -e "${RED}✗ Bucket no encontrado: ${BUCKET}${NC}"
    exit 1
fi

# Verificar Lambda
if aws lambda get-function --function-name "${FUNCTION_NAME}" &> /dev/null; then
    echo -e "${GREEN}✓ Lambda encontrado: ${FUNCTION_NAME}${NC}"
else
    echo -e "${RED}✗ Lambda no encontrado: ${FUNCTION_NAME}${NC}"
    exit 1
fi

echo ""

# 2. Crear documento de prueba
echo -e "${YELLOW}[2/6] Creando documento de prueba...${NC}"

TEST_FILE="/tmp/test-doc-${STUDENT_ID}.txt"
cat > "${TEST_FILE}" <<EOF
Introducción a RAG (Retrieval Augmented Generation)

RAG es una técnica que combina búsqueda semántica con modelos de lenguaje.
El proceso consiste en tres pasos principales:

1. Indexación: Los documentos se convierten en vectores (embeddings) y se almacenan en una base de datos vectorial como OpenSearch.

2. Recuperación: Cuando el usuario hace una pregunta, se convierte en un vector y se buscan los documentos más similares.

3. Generación: Los documentos recuperados se usan como contexto para que un LLM genere una respuesta precisa.

Ventajas de RAG:
- Reduce alucinaciones del modelo
- Permite actualizar conocimiento sin reentrenar
- Cita fuentes específicas
- Más eficiente que fine-tuning

Tecnologías usadas:
- AWS Bedrock para embeddings (Titan)
- OpenSearch para búsqueda vectorial
- Lambda para procesamiento serverless
- S3 para almacenamiento de documentos
EOF

echo -e "${GREEN}✓ Documento creado: ${TEST_FILE}${NC}"
echo ""

# 3. Subir documento a S3
echo -e "${YELLOW}[3/6] Subiendo documento a S3...${NC}"

aws s3 cp "${TEST_FILE}" "s3://${BUCKET}/documents/test-doc.txt"
echo -e "${GREEN}✓ Documento subido a s3://${BUCKET}/documents/test-doc.txt${NC}"
echo ""

# 4. Esperar procesamiento
echo -e "${YELLOW}[4/6] Esperando procesamiento del Lambda (10 segundos)...${NC}"
sleep 10
echo -e "${GREEN}✓ Procesamiento completado${NC}"
echo ""

# 5. Realizar queries de prueba
echo -e "${YELLOW}[5/6] Realizando queries de prueba...${NC}"
echo ""

# Query 1
echo -e "${BLUE}Query 1: ¿Qué es RAG?${NC}"
aws lambda invoke \
    --function-name "${FUNCTION_NAME}" \
    --payload '{"action":"query","question":"¿Qué es RAG?"}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/response1.json > /dev/null 2>&1

if [ -f /tmp/response1.json ]; then
    RESULT=$(cat /tmp/response1.json | jq -r '.body' | jq -r '.results[0].text' 2>/dev/null || echo "Error parsing response")
    if [ "$RESULT" != "Error parsing response" ] && [ "$RESULT" != "null" ]; then
        echo -e "${GREEN}✓ Resultado encontrado${NC}"
        echo -e "Score: $(cat /tmp/response1.json | jq -r '.body' | jq -r '.results[0].score')"
        echo -e "Texto: ${RESULT:0:100}..."
    else
        echo -e "${RED}✗ No se encontraron resultados${NC}"
    fi
else
    echo -e "${RED}✗ Error en la query${NC}"
fi
echo ""

# Query 2
echo -e "${BLUE}Query 2: ¿Cuáles son las ventajas de RAG?${NC}"
aws lambda invoke \
    --function-name "${FUNCTION_NAME}" \
    --payload '{"action":"query","question":"¿Cuáles son las ventajas de RAG?"}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/response2.json > /dev/null 2>&1

if [ -f /tmp/response2.json ]; then
    RESULT=$(cat /tmp/response2.json | jq -r '.body' | jq -r '.results[0].text' 2>/dev/null || echo "Error parsing response")
    if [ "$RESULT" != "Error parsing response" ] && [ "$RESULT" != "null" ]; then
        echo -e "${GREEN}✓ Resultado encontrado${NC}"
        echo -e "Score: $(cat /tmp/response2.json | jq -r '.body' | jq -r '.results[0].score')"
        echo -e "Texto: ${RESULT:0:100}..."
    else
        echo -e "${RED}✗ No se encontraron resultados${NC}"
    fi
else
    echo -e "${RED}✗ Error en la query${NC}"
fi
echo ""

# Query 3
echo -e "${BLUE}Query 3: ¿Qué tecnologías usa este proyecto?${NC}"
aws lambda invoke \
    --function-name "${FUNCTION_NAME}" \
    --payload '{"action":"query","question":"¿Qué tecnologías se usan en este proyecto?"}' \
    --cli-binary-format raw-in-base64-out \
    /tmp/response3.json > /dev/null 2>&1

if [ -f /tmp/response3.json ]; then
    RESULT=$(cat /tmp/response3.json | jq -r '.body' | jq -r '.results[0].text' 2>/dev/null || echo "Error parsing response")
    if [ "$RESULT" != "Error parsing response" ] && [ "$RESULT" != "null" ]; then
        echo -e "${GREEN}✓ Resultado encontrado${NC}"
        echo -e "Score: $(cat /tmp/response3.json | jq -r '.body' | jq -r '.results[0].score')"
        echo -e "Texto: ${RESULT:0:100}..."
    else
        echo -e "${RED}✗ No se encontraron resultados${NC}"
    fi
else
    echo -e "${RED}✗ Error en la query${NC}"
fi
echo ""

# 6. Mostrar logs recientes
echo -e "${YELLOW}[6/6] Logs recientes del Lambda:${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
aws logs tail "/aws/lambda/${FUNCTION_NAME}" --since 2m --format short 2>/dev/null || echo "No hay logs disponibles"
echo -e "${BLUE}----------------------------------------${NC}"
echo ""

# Resumen
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}   Test completado para ${STUDENT_ID}${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "Comandos útiles:"
echo -e "  Ver logs:     ${YELLOW}aws logs tail /aws/lambda/${FUNCTION_NAME} --follow${NC}"
echo -e "  Listar docs:  ${YELLOW}aws s3 ls s3://${BUCKET}/documents/${NC}"
echo -e "  Hacer query:  ${YELLOW}aws lambda invoke --function-name ${FUNCTION_NAME} --payload '{\"action\":\"query\",\"question\":\"tu pregunta\"}' response.json${NC}"
echo ""

# Cleanup
rm -f /tmp/response*.json
