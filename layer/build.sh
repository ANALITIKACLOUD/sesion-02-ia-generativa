#!/bin/bash
# Script para crear Lambda Layer con OpenSearch dependencies
# pandas, numpy y boto3 vienen del AWS SDK for pandas layer

set -e

echo "================================================"
echo "  Creando Lambda Layer - OpenSearch Dependencies"
echo "================================================"

LAYER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_DIR="$LAYER_DIR/python"

echo "Directorio Layer: $LAYER_DIR"
echo "Directorio Python: $PYTHON_DIR"

# Limpiar instalaciones previas
echo ""
echo "Limpiando instalaciones previas..."
if [ -d "$PYTHON_DIR" ]; then
    rm -rf "$PYTHON_DIR"
fi
mkdir -p "$PYTHON_DIR"

# Instalar dependencias en el directorio python/
echo ""
echo "Instalando dependencias desde requirements.txt..."
pip3 install -r "$LAYER_DIR/requirements.txt" -t "$PYTHON_DIR" --upgrade --no-cache-dir

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

if [ $MISSING -eq 1 ]; then
    exit 1
fi

# Limpiar archivos innecesarios para reducir tamaño
echo ""
echo "Limpiando archivos innecesarios..."
find "$PYTHON_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find "$PYTHON_DIR" -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
find "$PYTHON_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$PYTHON_DIR" -type f -name "*.pyo" -delete 2>/dev/null || true
find "$PYTHON_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$PYTHON_DIR" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find "$PYTHON_DIR" -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true

# Eliminar archivos de desarrollo y documentación
find "$PYTHON_DIR" -type f -name "*.md" -delete 2>/dev/null || true
find "$PYTHON_DIR" -type f -name "*.txt" -delete 2>/dev/null || true
find "$PYTHON_DIR" -type f -name "*.rst" -delete 2>/dev/null || true

# Calcular tamaño
echo ""
TOTAL_SIZE=$(du -sh "$LAYER_DIR" | cut -f1)
PYTHON_SIZE=$(du -sh "$PYTHON_DIR" | cut -f1)
echo "Tamaño total del layer: $TOTAL_SIZE"
echo "Tamaño del directorio python/: $PYTHON_SIZE"

echo ""
echo "================================================"
echo "  ✓ Lambda Layer creado exitosamente"
echo "================================================"
echo ""
echo "Este layer incluye:"
echo "  - opensearch-py"
echo "  - requests-aws4auth"
echo "  - boto3, requests y sus dependencias"
echo ""
echo "pandas y numpy vienen del AWS SDK for pandas layer (público)"
echo ""
echo "Siguiente paso:"
echo "  cd ../student && terraform apply"
