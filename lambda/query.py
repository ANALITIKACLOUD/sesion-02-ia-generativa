# lambda_query_agent.py
# Agente de consultas para aplicaciones BBVA - Versión Variabilizada
# Recibe pregunta → Busca en OpenSearch → Genera respuesta con Claude 3
 
import boto3
import json
import os
import re
from typing import Dict, List, Optional
from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth
 
# --- 1. CONFIGURACIÓN DESDE VARIABLES DE ENTORNO ---
 
# OpenSearch
OPENSEARCH_HOST = os.environ.get('OPENSEARCH_ENDPOINT', 'vpc-taller-rag-suxpeftnnyc7e2fxodbtrydn5m.us-east-1.es.amazonaws.com')
OPENSEARCH_INDEX = os.environ.get('OPENSEARCH_INDEX', 'rag-alumno01')
OPENSEARCH_PORT = int(os.environ.get('OPENSEARCH_PORT', '443'))
OPENSEARCH_SERVICE = os.environ.get('OPENSEARCH_SERVICE', 'es')  # 'es' para VPC
 
# AWS
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
 
# Bedrock
BEDROCK_EMBEDDING_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.titan-embed-text-v1')
BEDROCK_GENERATION_MODEL_ID = os.environ.get('BEDROCK_GENERATION_MODEL', 'anthropic.claude-3-sonnet-20240229-v1:0')
 
# Query
TOP_K_RESULTS = int(os.environ.get('TOP_K_RESULTS', '5'))
MAX_TOKENS = int(os.environ.get('MAX_TOKENS', '2048'))
 
# Performance
OPENSEARCH_POOL_SIZE = int(os.environ.get('OPENSEARCH_POOL_SIZE', '20'))
OPENSEARCH_TIMEOUT = int(os.environ.get('OPENSEARCH_TIMEOUT', '30'))
 
# --- 2. INICIALIZACIÓN DE CLIENTES ---
bedrock_runtime = boto3.client('bedrock-runtime', region_name=AWS_REGION)
 
credentials = boto3.Session().get_credentials()
auth = AWSV4SignerAuth(credentials, AWS_REGION, OPENSEARCH_SERVICE)
 
opensearch_client = OpenSearch(
    hosts=[{'host': OPENSEARCH_HOST, 'port': OPENSEARCH_PORT}],
    http_auth=auth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    pool_maxsize=OPENSEARCH_POOL_SIZE,
    timeout=OPENSEARCH_TIMEOUT
)
 
# --- 3. DETECCIÓN INTELIGENTE DE FILTROS ---
def extract_filters_from_question(question: str) -> Dict:
    """Detecta filtros basándose en keywords - CORREGIDO para CSV real."""
    filters = {}
    question_lower = question.lower()
   
    # Países
    countries = {
        'colombia': 'Colombia',
        'perú': 'Perú',
        'peru': 'Perú',
        'argentina': 'Argentina',
        'chile': 'Chile',
        'uruguay': 'Uruguay',
        'venezuela': 'Venezuela',
        'españa': 'España',
        'espana': 'España',
        'méxico': 'México',
        'mexico': 'México',
        'paraguay': 'Paraguay',
        'turquía': 'Turquía',
        'turquia': 'Turquía',
        'estados unidos': 'Estados Unidos'
    }
    for key, value in countries.items():
        if key in question_lower:
            filters['country'] = value
            break
   
    # ⚠️ CRITICIDAD - CORREGIDO con valores reales del CSV
    if any(word in question_lower for word in ['muy critica', 'muy crítica', 'muy criticas', 'muy críticas']):
        filters['critic_name'] = 'Muy Crítico'
    elif any(word in question_lower for word in ['critica', 'crítica', 'criticas', 'críticas', 'criticidad']):
        filters['critic_name'] = 'Crítico'
    elif any(word in question_lower for word in ['media', 'medio']):
        filters['critic_name'] = 'Medio'
    elif any(word in question_lower for word in ['baja', 'bajo']):
        filters['critic_name'] = 'Bajo'
   
    # Status - Corregido con todos los valores posibles
    if any(word in question_lower for word in ['activa', 'activas', 'activo', 'activos', 'en uso']):
        filters['is_active'] = True  # ✅ Usar campo computado
    elif any(word in question_lower for word in ['deprecada', 'deprecado', 'deprecadas']):
        filters['status'] = 'Deprecado'
    elif any(word in question_lower for word in ['mantenimiento']):
        filters['status'] = 'Mantenimiento'
    elif any(word in question_lower for word in ['desarrollo', 'en desarrollo']):
        filters['status'] = 'En Desarrollo'
   
    # DRP - Usar campo computado
    if 'drp' in question_lower or 'recuperación' in question_lower or 'recuperacion' in question_lower:
        filters['has_drp'] = True  # ✅ Ya está bien
   
    # Estratégico - Usar campo computado
    if any(word in question_lower for word in ['estratégica', 'estrategica', 'estratégicas', 'estrategico']):
        filters['is_strategic'] = True  # ✅ Ya está bien
   
    # Deploy
    if 'on premise' in question_lower or 'on-premise' in question_lower:
        filters['deploy'] = 'On-Premise'
    elif 'cloud' in question_lower or 'nube' in question_lower:
        # Detectar tipo específico de cloud
        if 'aws' in question_lower:
            filters['deploy'] = 'AWS'
        elif 'azure' in question_lower:
            filters['deploy'] = 'Azure'
        elif 'gcp' in question_lower or 'google' in question_lower:
            filters['deploy'] = 'GCP'
        elif 'ibm' in question_lower:
            filters['deploy'] = 'IBM Cloud'
        elif 'kyndryl' in question_lower:
            filters['deploy'] = 'Kyndryl'
        elif 'hybrid' in question_lower or 'híbrido' in question_lower or 'hibrido' in question_lower:
            filters['deploy'] = 'Hybrid Cloud'
        # Si no se detecta tipo específico, no filtrar por deploy
   
    return filters
 
# --- 4. FUNCIONES DE EMBEDDING Y BÚSQUEDA ---
def create_embedding(text: str) -> List[float]:
    """Genera embedding usando Amazon Bedrock."""
    try:
        body = json.dumps({"inputText": text})
        response = bedrock_runtime.invoke_model(
            body=body,
            modelId=BEDROCK_EMBEDDING_MODEL_ID,
            accept="application/json",
            contentType="application/json"
        )
        response_body = json.loads(response.get("body").read())
        return response_body.get("embedding")
    except Exception as e:
        print(f"Error creando embedding: {e}")
        return None
 
def search_opensearch(query_embedding: List[float], filters: Dict = None, top_k: int = TOP_K_RESULTS) -> Dict:
    """Busca en OpenSearch con filtros opcionales."""
    print(f"Buscando en OpenSearch con filtros: {filters}")
   
    search_body = {
        "size": top_k,
        "query": {
            "bool": {
                "must": [
                    {
                        "knn": {
                            "embedding": {
                                "vector": query_embedding,
                                "k": top_k * 2
                            }
                        }
                    }
                ]
            }
        },
        "_source": ["text_content", "metadata"]
    }
   
    # Aplicar filtros si existen
    if filters:
        filter_clauses = []
       
        for key, value in filters.items():
            if key in ['country', 'status', 'critic_name', 'deploy', 'app_type', 'quadrant']:
                filter_clauses.append({
                    "term": {f"metadata.{key}": value}
                })
            elif key in ['is_strategic', 'has_drp', 'is_active']:
                filter_clauses.append({
                    "term": {f"metadata.{key}": value}
                })
       
        if filter_clauses:
            search_body["query"]["bool"]["filter"] = filter_clauses
   
    try:
        response = opensearch_client.search(index=OPENSEARCH_INDEX, body=search_body)
       
        results = []
        for hit in response['hits']['hits']:
            results.append({
                'score': hit['_score'],
                'text': hit['_source']['text_content'],
                'metadata': hit['_source']['metadata']
            })
       
        print(f"Encontrados {len(results)} resultados")
        return {
            'total': response['hits']['total']['value'],
            'results': results
        }
    except Exception as e:
        print(f"Error en búsqueda: {e}")
        return {'total': 0, 'results': []}
 
# --- 5. GENERACIÓN DE RESPUESTA CON CLAUDE 3 ---
def generate_response(question: str, search_results: Dict, applied_filters: Dict) -> str:
    """Genera respuesta usando Claude 3 Sonnet."""
    print("Generando respuesta con Claude 3 Sonnet...")
   
    if not search_results['results']:
        return "No encontré información relevante en la base de datos de aplicaciones para responder tu pregunta."
   
    # Construir contexto enriquecido
    context_parts = []
    for idx, result in enumerate(search_results['results'][:TOP_K_RESULTS], 1):
        metadata = result['metadata']
        context_parts.append(f"""
Aplicación {idx}:
- Nombre: {metadata.get('name', 'N/A')}
- País: {metadata.get('country', 'N/A')}
- Criticidad: {metadata.get('critic_name', 'N/A')} (Score: {metadata.get('score', 'N/A')})
- Tipo: {metadata.get('app_type', 'N/A')} / {metadata.get('classif_type', 'N/A')}
- Deploy: {metadata.get('deploy', 'N/A')}
- Status: {metadata.get('status', 'N/A')}
- DRP: {metadata.get('drp', 'N/A')}
- Estratégico: {'Sí' if metadata.get('is_strategic') else 'No'}
- Dominio: {metadata.get('service_domain', 'N/A')} / {metadata.get('product_domain', 'N/A')}
- Owner: {metadata.get('owner', 'N/A')}
- Descripción: {result['text']}
""")
   
    context = "\n---\n".join(context_parts)
   
    # Información de filtros aplicados
    filters_info = ""
    if applied_filters:
        filters_info = f"\n**Filtros aplicados en la búsqueda:** {', '.join([f'{k}={v}' for k, v in applied_filters.items()])}"
   
    prompt = f"""Human: Eres un asistente experto en arquitectura de aplicaciones bancarias. Tu especialidad es analizar y explicar información sobre el portafolio de aplicaciones BBVA.
 
**INSTRUCCIONES:**
- Analiza el contexto proporcionado con información de aplicaciones
- Responde de forma concisa y directa
- Prioriza información de criticidad, status y características técnicas
- Si hay múltiples aplicaciones relevantes, menciona las más importantes
- Incluye datos clave: criticidad, deploy, DRP, dominio
- Responde siempre en español de forma profesional
- Si la información es incompleta, indícalo claramente
 
**CONTEXTO DE APLICACIONES:**
<context>
{context}
</context>
{filters_info}
 
**PREGUNTA DEL USUARIO:**
<question>{question}</question>
 
**FORMATO DE RESPUESTA ESPERADO:**
1. Respuesta directa a la pregunta
2. Datos clave relevantes
3. Observaciones técnicas si aplica
 
Mantén la respuesta concisa (máximo 250 palabras)."""
 
    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": MAX_TOKENS,
        "messages": [
            {
                "role": "user",
                "content": [{"type": "text", "text": prompt}]
            }
        ]
    })
   
    try:
        response = bedrock_runtime.invoke_model(
            body=body,
            modelId=BEDROCK_GENERATION_MODEL_ID,
            accept="application/json",
            contentType="application/json"
        )
       
        response_body = json.loads(response.get('body').read())
        answer = response_body.get('content', [{}])[0].get('text', '')
        print(f"Respuesta generada exitosamente")
        return answer
    except Exception as e:
        print(f"Error generando respuesta: {e}")
        return f"Error al generar respuesta: {str(e)}"
 
# --- 6. FUNCIÓN PRINCIPAL DE LAMBDA ---
def handler(event, context):
    """Handler principal optimizado para consultas de aplicaciones."""
    print(f"Evento recibido: {json.dumps(event)}")
   
    try:
        # Extraer pregunta del body
        body = json.loads(event.get('body', '{}'))
        question = body.get('question')
       
        if not question:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'El cuerpo de la solicitud debe contener una clave "question"'
                })
            }
       
        print(f"Pregunta recibida: {question}")
       
        # 1. Detectar filtros automáticamente
        filters = extract_filters_from_question(question)
        print(f"Filtros detectados: {filters}")
       
        # 2. Crear embedding de la pregunta
        query_embedding = create_embedding(question)
       
        if not query_embedding:
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({
                    'error': 'Error al crear embedding de la pregunta'
                })
            }
       
        # 3. Buscar en OpenSearch
        search_results = search_opensearch(query_embedding, filters)
       
        # 4. Generar respuesta con Claude 3
        final_answer = generate_response(question, search_results, filters)
       
        # 5. Retornar respuesta
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'answer': final_answer,
                'metadata': {
                    'total_results': search_results['total'],
                    'filters_applied': filters,
                    'model_used': BEDROCK_GENERATION_MODEL_ID
                }
            })
        }
       
    except json.JSONDecodeError as e:
        print(f"Error parseando JSON: {e}")
        return {
            'statusCode': 400,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'JSON inválido: {str(e)}'
            })
        }
    except Exception as e:
        print(f"Error en lambda_handler: {e}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'Error interno: {str(e)}'
            })
        }