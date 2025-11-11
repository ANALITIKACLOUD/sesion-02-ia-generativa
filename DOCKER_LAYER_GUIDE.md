# Guía Rápida: Construir Lambda Layer con Docker

## ¿Por qué Docker?

El problema con numpy y pandas es que tienen dependencias compiladas en C que deben coincidir exactamente con el runtime de Lambda. Cuando instalas con `pip` en tu máquina local (incluso WSL), puede que las versiones compiladas no sean compatibles con el ambiente de Lambda.

**Solución:** Usar la imagen oficial de AWS Lambda para compilar las dependencias en el mismo ambiente que usará Lambda en producción.

## Requisitos

### En Windows con WSL2:

1. **Docker Desktop para Windows**
   - Descarga: https://www.docker.com/products/docker-desktop
   - Instala y reinicia tu computadora
   - Abre Docker Desktop y espera a que inicie

2. **Habilitar integración con WSL2**
   - Docker Desktop → Settings → Resources → WSL Integration
   - Activa la integración con tu distribución Ubuntu
   - Apply & Restart

3. **Verificar instalación** (en WSL):
   ```bash
   docker --version
   docker ps
   ```

## Cómo usar

### Opción 1: Comando único (Recomendado)

```bash
cd /home/ap/code/a/prueba-open-search
make build-layer
```

### Opción 2: Manual

```bash
cd /home/ap/code/a/prueba-open-search/layer
chmod +x build-docker.sh
./build-docker.sh
```

## ¿Qué hace el script?

1. **Verifica Docker** → Confirma que Docker está instalado y corriendo
2. **Construye imagen** → Usa `public.ecr.aws/lambda/python:3.9` (imagen oficial de AWS)
3. **Instala dependencias** → Ejecuta `pip install` dentro del contenedor
4. **Extrae archivos** → Copia `/opt/python/` del contenedor a tu máquina
5. **Limpia** → Elimina contenedor temporal

## Ventajas

✅ **Compatibilidad garantizada**: Mismo runtime que Lambda  
✅ **Sin problemas de numpy**: Compilado correctamente para Lambda  
✅ **Reproducible**: Mismo resultado en cualquier máquina  
✅ **No contamina tu sistema**: Todo ocurre en el contenedor  

## Resultado

Después de ejecutar el script, tendrás:

```
layer/
└── python/
    ├── pandas/       ← Compilado para Lambda
    ├── numpy/        ← Compilado para Lambda
    ├── opensearchpy/
    ├── boto3/
    └── ...
```

Este directorio será empaquetado por Terraform en un ZIP y subido como Lambda Layer.

## Troubleshooting

### Docker no está instalado
```bash
❌ Error: Docker no está instalado
```
**Solución:** Instala Docker Desktop para Windows

### Docker no está corriendo
```bash
❌ Error: Docker no está corriendo
```
**Solución:** Abre Docker Desktop y espera a que inicie

### Error de permisos
```bash
ERROR: permission denied while trying to connect to Docker daemon
```
**Solución:** En Docker Desktop → Settings → General → Marca "Use WSL 2 based engine"

### Error al descargar imagen
```bash
Error response from daemon: pull access denied
```
**Solución:** 
```bash
docker logout public.ecr.aws
docker pull public.ecr.aws/lambda/python:3.9
```

## Verificación

Después del build exitoso, verifica:

```bash
# Ver tamaño del layer
du -sh /home/ap/code/a/prueba-open-search/layer/python

# Verificar que pandas existe
ls /home/ap/code/a/prueba-open-search/layer/python/pandas

# Verificar que numpy existe
ls /home/ap/code/a/prueba-open-search/layer/python/numpy
```

## Deploy

Una vez construido el layer:

```bash
cd /home/ap/code/a/prueba-open-search/student
terraform apply
```

Terraform creará:
1. ZIP del layer desde `layer/python/`
2. Lambda Layer version en AWS
3. Lambda Function con el layer adjunto

## Alternativa sin Docker

Si realmente no puedes usar Docker, hay un plan B:

```bash
make build-layer-no-docker
```

Pero este método puede tener problemas con numpy. El método con Docker es **altamente recomendado**.

## Tiempo estimado

- Primera vez: ~5-10 minutos (descarga imagen Docker + instala dependencias)
- Siguiente vez: ~2-3 minutos (usa cache de Docker)

## Tamaño esperado

- Layer descomprimido: ~100-120 MB
- Layer comprimido (ZIP): ~30-40 MB

Ambos dentro de los límites de AWS Lambda (250 MB / 50 MB).
