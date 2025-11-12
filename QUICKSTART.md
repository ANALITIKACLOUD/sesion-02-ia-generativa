# Guía Rápida - Alumno

## 🚀 Setup Rápido (5 minutos)

### 1. Obtén tu Student ID
Tu instructor te asignará un ID único:
- Formato: `alumnoXX` donde XX = 01-35
- Ejemplo: `alumno01`

### 2. Configura tu ambiente

```bash
# Clonar repositorio (si no lo hiciste)
git clone <repo-url>
cd prueba-open-search

# Ir a carpeta student
cd student

# Copiar template de variables
cp terraform.tfvars.example terraform.tfvars

# Editar con tu Student ID
vim terraform.tfvars
# Cambiar: alumno_id = "alumnoXX"
```

### 3. Obtén configuración compartida

Tu instructor te proporcionará un archivo `shared-outputs.json`. Cópialo a la raíz del proyecto.

```bash
# Copiar shared-outputs.json (el instructor lo compartirá)
# El archivo debe estar en la raíz: ../shared-outputs.json
```

### 4. Ejecuta el script de setup

```bash
# Desde la raíz del proyecto
cd ..

# IMPORTANTE: Empaquetar Lambda con dependencias primero
cd lambda
./build.sh

# Ahora configurar student
cd ..
bash scripts/setup-student.sh
```

Este script te pedirá tu Student ID y configurará todo automáticamente.

### 5. Despliega tu infraestructura

```bash
cd student

# Inicializar Terraform con tu alumno_id
# Reemplaza alumno01 con tu ID asignado
terraform init -backend-config="key=alumnos/alumno01/terraform.tfstate"

# Aplicar
terraform apply
```

Revisa los recursos que se crearán y escribe `yes` para confirmar.

---

## 📝 Probar el RAG

### Opción 1: Usando el script de prueba (recomendado)

```bash
# Desde la raíz del proyecto
bash scripts/test-rag.sh alumno01
```

Este script:
1. Verifica tu infraestructura
2. Sube un documento de prueba
3. Espera el procesamiento
4. Hace 3 queries de ejemplo
5. Muestra los logs

### Opción 2: Manual

#### a) Subir un documento

```bash
# Crear documento de prueba
cat > test.txt <<EOF
Este es un documento sobre Inteligencia Artificial.
Machine Learning es una rama de la IA que permite a las máquinas aprender de datos.
Los modelos de lenguaje como GPT pueden generar texto coherente.
EOF

# Subir a S3
aws s3 cp test.txt s3://rag-alumno01/documents/
```

#### b) Esperar procesamiento (10 segundos)
El Lambda se activa automáticamente cuando subes el archivo.

#### c) Hacer una query

```bash
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action":"query","question":"¿Qué es Machine Learning?"}' \
  --cli-binary-format raw-in-base64-out \
  response.json

# Ver resultado
cat response.json | jq .
```

---

## 🛠️ Comandos Útiles

### Ver logs del Lambda
```bash
aws logs tail /aws/lambda/rag-lambda-alumno01 --follow
```

### Listar documentos en S3
```bash
aws s3 ls s3://rag-alumno01/documents/
```

### Hacer otra query
```bash
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action":"query","question":"Tu pregunta aquí"}' \
  --cli-binary-format raw-in-base64-out \
  response.json
```

### Indexar documento manualmente
```bash
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action":"index","bucket":"rag-alumno01","key":"documents/test.txt"}' \
  --cli-binary-format raw-in-base64-out \
  response.json
```

---

## ❓ Troubleshooting

### Error: "Lambda timeout"
**Causa**: Lambda no puede conectarse a Bedrock o OpenSearch

**Solución**: Verifica con tu instructor que los VPC endpoints estén activos

### Error: "Access denied to Bedrock"
**Causa**: IAM permissions incorrectos

**Solución**: 
```bash
# Verificar rol de Lambda
aws iam get-role --role-name rag-lambda-role-alumno01

# Si hay problemas, destroy y vuelve a aplicar
terraform destroy
terraform apply
```

### Error: "Index not found"
**Causa**: No se ha indexado ningún documento aún

**Solución**: 
```bash
# Sube al menos un documento primero
aws s3 cp test.txt s3://rag-alumno01/documents/

# O crea el índice manualmente
aws lambda invoke \
  --function-name rag-lambda-alumno01 \
  --payload '{"action":"create_index"}' \
  response.json
```

### No se procesan los documentos
**Causa**: S3 notification no configurado

**Solución**:
```bash
# Verificar notificación
aws s3api get-bucket-notification-configuration \
  --bucket rag-alumno01

# Si no hay output, re-aplica Terraform
terraform apply
```

### Ver errores específicos
```bash
# Ver logs detallados
aws logs tail /aws/lambda/rag-lambda-alumno01 --since 10m

# Ver solo errores
aws logs tail /aws/lambda/rag-lambda-alumno01 --since 10m --filter-pattern "ERROR"
```

---

## 🧹 Limpieza al Final del Taller

```bash
cd student
terraform destroy
```

Confirma con `yes` cuando te pregunte.

**Importante**: Esto eliminará:
- Tu Lambda function
- Tu S3 bucket (y todos los documentos dentro)
- Todas las configuraciones

**No eliminará**:
- La infraestructura compartida (VPC, OpenSearch, etc.)
- Eso lo hace el instructor al final

---

## 📚 Recursos Adicionales

### Documentación Lambda
Ver `lambda/README.md` para detalles sobre:
- Estructura del código
- Variables de entorno
- Formato de eventos
- Testing local

### Arquitectura
Ver `ARCHITECTURE.md` para entender:
- Cómo funciona el networking
- Flujo de datos
- Security groups
- Permisos IAM

### Comandos AWS CLI
Ver `AWS_CLI_CHEATSHEET.md` para:
- Comandos útiles de S3
- Comandos de Lambda
- Comandos de Logs

---

## 🎓 Conceptos Clave

### ¿Qué es RAG?
RAG (Retrieval Augmented Generation) combina:
1. **Búsqueda semántica**: Encontrar documentos relevantes
2. **Generación con contexto**: Usar esos documentos para responder

### Componentes de tu Pipeline
1. **S3**: Almacena documentos originales
2. **Lambda**: Procesa y genera embeddings
3. **Bedrock**: Genera vectores (embeddings) de 1536 dimensiones
4. **OpenSearch**: Búsqueda vectorial (KNN)

### Flujo Completo
```
Documento → S3 → Lambda → Bedrock (embedding) → OpenSearch (index)
Pregunta → Lambda → Bedrock (embedding) → OpenSearch (KNN search) → Resultados
```

---

## 💡 Tips

1. **Documentos cortos**: Para el taller, usa documentos de < 1KB
2. **Queries específicas**: Preguntas concretas funcionan mejor
3. **Espera procesamiento**: Dale 5-10 segundos después de subir un documento
4. **Revisa logs**: Si algo falla, los logs tienen la respuesta

---

## ✅ Checklist de Éxito

- [ ] Infraestructura desplegada sin errores
- [ ] Documento subido a S3
- [ ] Lambda procesó el documento (ver logs)
- [ ] Query retorna resultados relevantes
- [ ] Entiendo cómo funciona el pipeline RAG

---

**¿Problemas?** Levanta la mano y llama al instructor 👋
