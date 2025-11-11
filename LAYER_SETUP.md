# Lambda Layer Setup - Guía Completa

## ¿Qué es un Lambda Layer?

Un Lambda Layer es una forma de empaquetar y compartir dependencias entre múltiples funciones Lambda. En lugar de incluir todas las librerías en cada función, las empaquetas una vez en un layer y lo reutilizas.

## Ventajas

1. **Reducción de tamaño**: El código Lambda solo contiene tu lógica
2. **Velocidad de deployment**: No subes dependencias en cada deploy
3. **Reutilización**: Un layer sirve para múltiples funciones
4. **Evitar límites**: AWS Lambda tiene límite de 50MB comprimido para el código

## Estructura del Proyecto

```
prueba-open-search/
├── layer/                      # Lambda Layer con dependencias
│   ├── python/                 # Dependencias instaladas aquí
│   │   ├── pandas/
│   │   ├── numpy/
│   │   ├── opensearchpy/
│   │   └── ...
│   ├── requirements.txt        # Lista de dependencias
│   ├── build.sh               # Script de construcción
│   └── README.md
│
├── lambda/                     # Código de la función Lambda (solo lógica)
│   ├── indexer.py
│   ├── query.py
│   ├── shared.py
│   ├── clean.sh               # Limpia dependencias locales
│   └── README.md
│
├── student/                    # Terraform
│   ├── layer.tf               # Define el Lambda Layer
│   ├── lambda.tf              # Lambda con referencia al layer
│   ├── s3.tf
│   └── ...
│
└── Makefile                    # Comandos simplificados
```

## Proceso de Build y Deploy

### Opción 1: Usando Make (Recomendado)

```bash
# En el directorio raíz del proyecto
make package-lambda    # Construye layer y limpia lambda
make deploy-student    # Despliega todo con Terraform
```

### Opción 2: Manual (Paso a Paso)

```bash
# 1. Construir el Lambda Layer
cd layer
chmod +x build.sh
./build.sh

# 2. Limpiar dependencias del código Lambda
cd ../lambda
chmod +x clean.sh
./clean.sh

# 3. Desplegar con Terraform
cd ../student
terraform init
terraform plan
terraform apply
```

## ¿Qué hace cada script?

### `layer/build.sh`
1. Limpia instalaciones previas en `layer/python/`
2. Instala todas las dependencias desde `requirements.txt`
3. Limpia archivos innecesarios (tests, docs, etc.)
4. Verifica que pandas, numpy, opensearch-py estén instalados
5. Muestra el tamaño total

### `lambda/clean.sh`
1. Elimina todas las dependencias del directorio lambda
2. Mantiene solo los archivos `.py` de tu código
3. Muestra qué archivos quedan

### `student/layer.tf` (Terraform)
1. Empaqueta `layer/python/` en un ZIP
2. Crea el Lambda Layer en AWS
3. Genera un ARN que se usa en `lambda.tf`

### `student/lambda.tf` (Terraform)
1. Empaqueta el código Lambda (solo `.py`)
2. Crea la función Lambda
3. **Adjunta el Layer**: `layers = [aws_lambda_layer_version.dependencies.arn]`

## Límites de AWS Lambda Layer

- **Tamaño descomprimido**: 250 MB (máximo)
- **Tamaño comprimido**: 50 MB (máximo)
- **Layers por función**: 5 (máximo)

Nuestro layer con pandas + numpy + opensearch-py debería estar alrededor de 80-120 MB descomprimido.

## Verificación

Después del deploy, verifica en AWS Console:

1. **Lambda → Layers**: Deberías ver `rag-dependencies-{student_id}`
2. **Lambda → Functions**: Tu función debe mostrar el layer adjunto
3. **Función → Code**: El tamaño del deployment package será muy pequeño (~1-5MB)

## Troubleshooting

### Error: "Layer is too large"
El layer excede 250 MB descomprimido. Soluciones:
- Eliminar dependencias innecesarias
- Usar versiones más ligeras (ej: `pandas<2.0.0`)
- Dividir en múltiples layers

### Error: "No module named 'pandas'"
El layer no está adjunto correctamente:
1. Verifica en `lambda.tf`: `layers = [aws_lambda_layer_version.dependencies.arn]`
2. Redeploy: `terraform apply`

### Cambios en dependencias no se reflejan
El hash del layer no cambió:
1. Reconstruye el layer: `cd layer && ./build.sh`
2. Terraform detectará el cambio automáticamente: `terraform apply`

## Testing Local con Layer

Para probar localmente necesitas las dependencias instaladas:

```bash
# Opción 1: Instalar en lambda/ (temporal, solo para testing)
cd lambda
pip install -r ../layer/requirements.txt -t .

# Opción 2: Usar virtualenv
python -m venv venv
source venv/bin/activate
pip install -r layer/requirements.txt
cd lambda
python indexer.py
```

Recuerda limpiar después:
```bash
cd lambda
./clean.sh
```

## Comandos Útiles del Makefile

```bash
make help              # Ver todos los comandos
make build-layer       # Solo construir el layer
make clean-lambda      # Solo limpiar lambda
make package-lambda    # Ambos (layer + clean)
make deploy-student    # Desplegar todo
make clean            # Limpiar archivos temporales
```

## Flujo de Trabajo Recomendado

1. **Primera vez**:
   ```bash
   make package-lambda
   make deploy-student
   ```

2. **Cambios en código Lambda**:
   ```bash
   cd student
   terraform apply    # Solo actualiza la función
   ```

3. **Cambios en dependencias**:
   ```bash
   make build-layer   # Reconstruye layer
   make deploy-student
   ```

4. **Agregar nueva dependencia**:
   ```bash
   # Editar layer/requirements.txt
   make build-layer
   make deploy-student
   ```

## Ventajas de este Setup

✅ Código Lambda muy pequeño (~1-5 MB)  
✅ Deployments rápidos cuando solo cambia código  
✅ Pandas disponible para procesamiento de datos  
✅ Fácil agregar nuevas dependencias  
✅ Evita límite de 50MB en código comprimido  
✅ Reutilizable entre múltiples funciones Lambda  

## Referencias

- [AWS Lambda Layers](https://docs.aws.amazon.com/lambda/latest/dg/configuration-layers.html)
- [Lambda Deployment Package Size Limits](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [Python Packages for Lambda](https://docs.aws.amazon.com/lambda/latest/dg/python-package.html)
