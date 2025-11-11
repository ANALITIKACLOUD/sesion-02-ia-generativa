#!/bin/bash
# Script para limpiar dependencias del directorio lambda
# Las dependencias ahora están en el Lambda Layer

set -e

echo "================================================"
echo "  Limpiando Dependencias de Lambda"
echo "================================================"

LAMBDA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Directorio Lambda: $LAMBDA_DIR"

echo ""
echo "Limpiando dependencias instaladas (ahora en layer)..."

# Lista de carpetas de dependencias a eliminar
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
    "pandas"
    "numpy"
    "pytz"
    "numpy.libs"
    "boto3"
    "botocore"
    "s3transfer"
    "jmespath"
    "events"
)

for dep in "${DEPS_TO_CLEAN[@]}"; do
    if [ -d "$LAMBDA_DIR/$dep" ]; then
        echo "  Eliminando: $dep"
        rm -rf "$LAMBDA_DIR/$dep"
    fi
done

# Limpiar archivos de metadatos
find "$LAMBDA_DIR" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find "$LAMBDA_DIR" -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
find "$LAMBDA_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$LAMBDA_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$LAMBDA_DIR" -type f -name "*.pyo" -delete 2>/dev/null || true

# Eliminar binarios si existen
if [ -d "$LAMBDA_DIR/bin" ]; then
    echo "  Eliminando: bin/"
    rm -rf "$LAMBDA_DIR/bin"
fi

echo ""
echo "Archivos Python de la función Lambda que quedan:"
find "$LAMBDA_DIR" -maxdepth 1 -name "*.py" -type f | while read file; do
    echo "  ✓ $(basename "$file")"
done

# Calcular tamaño
echo ""
TOTAL_SIZE=$(du -sh "$LAMBDA_DIR" | cut -f1)
echo "Tamaño del código Lambda (sin dependencias): $TOTAL_SIZE"

echo ""
echo "================================================"
echo "  ✓ Limpieza completada"
echo "================================================"
echo ""
echo "Las dependencias ahora están en el Lambda Layer."
echo "Siguiente paso: cd ../layer && ./build.sh"
