.PHONY: help setup-shared deploy-shared destroy-shared outputs setup-student test clean

help: ## Mostrar ayuda
	@echo "Taller RAG - Comandos disponibles:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $1, $2}'

preflight: ## Ejecutar pre-flight checks
	@bash scripts/preflight-check.sh

# ============================================
# COMANDOS PARA INSTRUCTOR
# ============================================

setup-shared: ## Inicializar infraestructura compartida
	cd shared && terraform init

deploy-shared: ## Desplegar infraestructura compartida
	cd shared && terraform apply

destroy-shared: ## Destruir infraestructura compartida
	@echo "⚠️  ADVERTENCIA: Esto eliminará toda la infraestructura compartida"
	@echo "Presiona CTRL+C para cancelar, o ENTER para continuar..."
	@read dummy
	cd shared && terraform destroy

outputs: ## Exportar outputs de shared a JSON
	cd shared && terraform output -json > ../shared-outputs.json
	@echo "✓ Outputs exportados a shared-outputs.json"

# ============================================
# COMANDOS PARA ESTUDIANTES
# ============================================

setup-student: ## Configurar ambiente de estudiante
	@bash scripts/setup-student.sh

deploy-student: ## Desplegar infraestructura de estudiante
	cd student && terraform apply

destroy-student: ## Destruir infraestructura de estudiante
	cd student && terraform destroy

test: ## Probar infraestructura RAG
	@if [ -z "$(STUDENT_ID)" ]; then \
		echo "Error: Especifica STUDENT_ID"; \
		echo "Ejemplo: make test STUDENT_ID=alumno01"; \
		exit 1; \
	fi
	@bash scripts/test-rag.sh $(STUDENT_ID)

# ============================================
# COMANDOS DE UTILIDAD
# ============================================

clean: ## Limpiar archivos temporales
	find . -name "*.tfstate*" -type f -delete
	find . -name ".terraform.lock.hcl" -type f -delete
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "*.pyc" -type f -delete
	rm -f student/lambda_function.zip
	rm -f student/lambda_layer.zip
	rm -rf layer/python/*
	@echo "✓ Archivos temporales eliminados"

format: ## Formatear código Terraform
	terraform fmt -recursive .

validate-shared: ## Validar configuración de shared
	cd shared && terraform validate

validate-student: ## Validar configuración de student
	cd student && terraform validate

# ============================================
# COMANDOS AVANZADOS
# ============================================

package-lambda: ## Empaquetar código Lambda con dependencias
	@echo "Empaquetando Lambda con Layers..."
	@echo ""
	@echo "Paso 1: Construyendo OpenSearch Layer..."
	cd layer && chmod +x build.sh && bash build.sh
	@echo ""
	@echo "Paso 2: Limpiando código Lambda..."
	cd lambda && chmod +x clean.sh && bash clean.sh
	@echo ""
	@echo "✓ Lambda y Layers listos para desplegar"
	@echo ""
	@echo "Layers utilizados:"
	@echo "  1. AWS SDK for pandas (público) - pandas, numpy, boto3"
	@echo "  2. OpenSearch (custom) - opensearch-py, requests-aws4auth"

build-layer: ## Construir solo el Lambda Layer de OpenSearch
	@echo "Construyendo OpenSearch Layer..."
	cd layer && chmod +x build.sh && bash build.sh
	@echo ""
	@echo "Nota: pandas y numpy vienen del AWS SDK for pandas layer (público)"

build-layer-no-docker: ## Alias para build-layer (no usa Docker)
	@make build-layer

clean-lambda: ## Limpiar dependencias del código Lambda
	@echo "Limpiando dependencias del código Lambda..."
	cd lambda && chmod +x clean.sh && bash clean.sh

check-quotas: ## Verificar límites de servicio AWS
	@echo "Verificando límites de servicio..."
	@echo ""
	@echo "VPC Endpoints:"
	aws service-quotas get-service-quota \
		--service-code vpc \
		--quota-code L-45FE3B85 \
		--query 'Quota.Value' \
		--output text || echo "No disponible"
	@echo ""
	@echo "Lambda concurrent executions:"
	aws service-quotas get-service-quota \
		--service-code lambda \
		--quota-code L-B99A9384 \
		--query 'Quota.Value' \
		--output text || echo "No disponible"

logs: ## Ver logs del Lambda (requiere STUDENT_ID)
	@if [ -z "$(STUDENT_ID)" ]; then \
		echo "Error: Especifica STUDENT_ID"; \
		echo "Ejemplo: make logs STUDENT_ID=alumno01"; \
		exit 1; \
	fi
	aws logs tail /aws/lambda/rag-lambda-$(STUDENT_ID) --follow

list-students: ## Listar estudiantes activos
	@echo "Estudiantes con infraestructura desplegada:"
	@aws s3 ls s3://taller-rag-terraform-state/students/ | awk '{print $$2}' | sed 's/\///'
