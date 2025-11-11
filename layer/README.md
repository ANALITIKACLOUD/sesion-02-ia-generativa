# Lambda Layer - OpenSearch Dependencies

Este directorio contiene un layer pequeño solo con opensearch-py y requests-aws4auth.

## Estrategia de Layers

Para evitar problemas de compatibilidad con pandas y numpy, usamos **dos layers**:

### 1. AWS SDK for pandas (Layer Público)
- **ARN:** `arn:aws:lambda:us-east-1:336392948345:layer:AWSSDKPandas-Python39:15`
- **Mantenido por:** AWS
- **Incluye:** pandas 2.0.3, numpy 1.24.3, boto3, pyarrow, s3fs, etc.
- **Pre-compilado y optimizado** para el runtime de Lambda
- **Sin problemas de compatibilidad**

### 2. OpenSearch Layer (Custom - Este Directorio)
- **Incluye:** opensearch-py, requests-aws4auth
- **Ligero:** ~5-10 MB
- **Fácil de mantener**

## Build

```bash
cd layer
chmod +x build.sh
./build.sh
```

Esto instala solo opensearch-py y requests-aws4auth en el directorio `python/`.

## Estructura

```
layer/
├── python/              # Dependencias instaladas
│   ├── opensearchpy/
│   ├── requests_aws4auth/
│   ├── requests/
│   └── ...
├── requirements.txt     # Solo opensearch-py y requests-aws4auth
├── build.sh            # Script de construcción
└── README.md           # Este archivo
```

## Uso en Lambda

La función Lambda tendrá acceso a:

```python
# Del AWS SDK for pandas layer
import pandas as pd
import numpy as np
import boto3

# Del OpenSearch layer custom
from opensearchpy import OpenSearch
from requests_aws4auth import AWS4Auth
```

## Ventajas

✅ **Sin problemas de numpy**: Usamos el layer oficial de AWS pre-compilado  
✅ **Siempre actualizado**: AWS mantiene el layer con las últimas versiones  
✅ **Layer pequeño**: Solo ~5-10 MB en lugar de ~100+ MB  
✅ **Deploy rápido**: Menos datos para subir  
✅ **Sin Docker**: No requiere herramientas adicionales  

## Referencia

- [AWS SDK for pandas Layers](https://aws-sdk-pandas.readthedocs.io/en/stable/layers.html)
- [Lista completa de layers por región](https://github.com/aws/aws-sdk-pandas/releases)

## Límites

- Lambda puede usar hasta **5 layers** simultáneamente
- Estamos usando **2 layers** (AWS SDK + OpenSearch)
- Espacio disponible: 3 layers más si fuera necesario
