#!/bin/bash
# Script para construir Lambda Layer usando Docker
# Garantiza compatibilidad 100% con el runtime de Lambda

set -e

echo "================================================"
echo "  Construyendo Lambda Layer con Docker"
echo "================================================"

LAYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_DIR="$LAYER_DIR/python"

echo "Directorio Layer: $LAYER_DIR"
echo ""

# Verificar que Docker está instalado
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker no está instalado"
    echo "Instala Docker Desktop para Windows: https://www.docker.com/products/docker-desktop"
    exit 1
fi

# Verificar que Docker está corriendo
if ! docker info &> /dev/null; then
    echo "❌ Error: Docker no está corriendo"
    echo "Inicia Docker Desktop y vuelve a intentar"
    exit 1
fi

echo "✓ Docker está instalado y corriendo"
echo ""

# Limpiar instalaciones previas
echo "Limpiando instalaciones previas..."
if [ -d "$PYTHON_DIR" ]; then
    rm -rf "$PYTHON_DIR"
fi
mkdir -p "$PYTHON_DIR"

# Construir imagen Docker
echo ""
echo "Construyendo imagen Docker con runtime de Lambda..."
docker build -t lambda-layer-builder "$LAYER_DIR"

# Crear contenedor temporal
echo ""
echo "Creando contenedor temporal..."
CONTAINER_ID=$(docker create lambda-layer-builder)

# Copiar dependencias del contenedor
echo ""
echo "Copiando dependencias desde el contenedor..."
docker cp "$CONTAINER_ID:/opt/python/." "$PYTHON_DIR/"

# Limpiar contenedor
echo ""
echo "Limpiando contenedor temporal..."
docker rm "$CONTAINER_ID"

# Verificar instalación
echo ""
echo "Verificando instalación..."
MISSING=0

if [ -d "$PYTHON_DIR/opensearchpy" ]; then
    echo "✓ opensearch-py instalado"
else
    echo "✗ ERROR: opensearch-py no se instaló"
    MISSING=1
fi

if [ -d "$PYTHON_DIR/requests_aws4auth" ]; then
    echo "✓ requests-aws4auth instalado"
else
    echo "✗ ERROR: requests-aws4auth no se instaló"
    MISSING=1
fi

if [ -d "$PYTHON_DIR/pandas" ]; then
    echo "✓ pandas instalado"
else
    echo "✗ ERROR: pandas no se instaló"
    MISSING=1
fi

if [ -d "$PYTHON_DIR/numpy" ]; then
    echo "✓ numpy instalado"
else
    echo "✗ ERROR: numpy no se instaló"
    MISSING=1
fi

if [ $MISSING -eq 1 ]; then
    exit 1
fi

# Calcular tamaño
echo ""
TOTAL_SIZE=$(du -sh "$LAYER_DIR" | cut -f1)
PYTHON_SIZE=$(du -sh "$PYTHON_DIR" | cut -f1)
echo "Tamaño total del layer: $TOTAL_SIZE"
echo "Tamaño del directorio python/: $PYTHON_SIZE"

# Verificar límite de tamaño (250MB descomprimido)
PYTHON_SIZE_MB=$(du -sm "$PYTHON_DIR" | cut -f1)
if [ $PYTHON_SIZE_MB -gt 240 ]; then
    echo ""
    echo "⚠️  WARNING: El layer es muy grande ($PYTHON_SIZE_MB MB)"
    echo "    Límite de Lambda Layer: 250 MB descomprimido"
fi

echo ""
echo "================================================"
echo "  ✓ Lambda Layer creado exitosamente"
echo "================================================"
echo ""
echo "Siguiente paso:"
echo "  cd ../student && terraform apply"
echo ""
echo "El layer incluye:"
echo "  - boto3, opensearch-py, requests-aws4auth"
echo "  - pandas, numpy (compilados para Lambda runtime)"
echo "  - todas las dependencias necesarias"
echo ""
echo "Construido con: AWS Lambda Python 3.9 runtime oficial"
