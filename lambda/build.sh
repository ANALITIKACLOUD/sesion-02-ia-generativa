#!/bin/bash
# Script para empaquetar Lambda con dependencias

set -e

echo "================================================"
echo "  Empaquetando Lambda con Dependencias"
echo "================================================"

LAMBDA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Directorio Lambda: $LAMBDA_DIR"

# Limpiar instalaciones previas
echo ""
echo "Limpiando instalaciones previas..."
find "$LAMBDA_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$LAMBDA_DIR" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find "$LAMBDA_DIR" -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true

# Lista de carpetas de dependencias a limpiar
DEPS_TO_CLEAN=(
    "opensearchpy"
    "opensearch_py"
    "requests_aws4auth"
    "requests"
    "urllib3"
    "certifi"
    "charset_normalizer"
    "idna"
    "six"
    "dateutil"
    "python_dateutil"
    "elastic_transport"
)

for dep in "${DEPS_TO_CLEAN[@]}"; do
    if [ -d "$LAMBDA_DIR/$dep" ]; then
        echo "  Eliminando: $dep"
        rm -rf "$LAMBDA_DIR/$dep"
    fi
done

# Instalar dependencias
echo ""
echo "Instalando dependencias desde requirements.txt..."
pip3 install -r "$LAMBDA_DIR/requirements.txt" -t "$LAMBDA_DIR" --upgrade

# Verificar instalación
echo ""
echo "Verificando instalación..."
if [ -d "$LAMBDA_DIR/opensearchpy" ]; then
    echo "✓ opensearch-py instalado"
else
    echo "✗ ERROR: opensearch-py no se instaló"
    exit 1
fi

if [ -d "$LAMBDA_DIR/requests_aws4auth" ]; then
    echo "✓ requests-aws4auth instalado"
else
    echo "✗ ERROR: requests-aws4auth no se instaló"
    exit 1
fi

# Limpiar archivos innecesarios para reducir tamaño
echo ""
echo "Limpiando archivos innecesarios..."
find "$LAMBDA_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find "$LAMBDA_DIR" -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
find "$LAMBDA_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$LAMBDA_DIR" -type f -name "*.pyo" -delete 2>/dev/null || true
find "$LAMBDA_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

# Calcular tamaño
echo ""
TOTAL_SIZE=$(du -sh "$LAMBDA_DIR" | cut -f1)
echo "Tamaño total del paquete: $TOTAL_SIZE"

echo ""
echo "================================================"
echo "  ✓ Empaquetado completado exitosamente"
echo "================================================"
echo ""
echo "Siguiente paso: cd ../student && terraform apply"
