"""
VERSIÓN 6 - RAG con Exact Match + Aggregations
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Autor: Analitika Team
Versión: 6.0
Fecha: 2025-01-09
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

import boto3
import json
import os
import re
from typing import Dict, List, Optional, Any
from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth
from datetime import datetime
import logging
from botocore.exceptions import ClientError

# ==================== JSON ENDPOINT =====================
s3 = boto3.client('s3')

# ==================== LOGGING ====================
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# ==================== CONFIGURACIÓN ====================
ALUMNO_ID = os.environ.get('ALUMNO_ID')
API_GATEWAY_ENDPOINT = os.environ.get('API_GATEWAY_ENDPOINT')
OPENSEARCH_HOST = os.environ.get('OPENSEARCH_ENDPOINT', '')
OPENSEARCH_INDEX = os.environ.get('OPENSEARCH_INDEX', '')
OPENSEARCH_PORT = int(os.environ.get('OPENSEARCH_PORT', '443'))
OPENSEARCH_SERVICE = os.environ.get('OPENSEARCH_SERVICE', 'es')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
BEDROCK_EMBEDDING_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.titan-embed-text-v1')
BEDROCK_GENERATION_MODEL_ID = os.environ.get('BEDROCK_GENERATION_MODEL', 'anthropic.claude-3-sonnet-20240229-v1:0')
TOP_K_RESULTS = int(os.environ.get('TOP_K_RESULTS', '15'))
MAX_TOKENS = int(os.environ.get('MAX_TOKENS', '3000'))
OPENSEARCH_POOL_SIZE = int(os.environ.get('OPENSEARCH_POOL_SIZE', '20'))
OPENSEARCH_TIMEOUT = int(os.environ.get('OPENSEARCH_TIMEOUT', '30'))
BUCKET = os.environ.get('S3_BUCKET')

# ==================== CLIENTES AWS ====================
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

# ==================== VALIDACIÓN MANUAL (Sin Pydantic) ====================
def validate_response(data: Dict) -> Dict:
    """
    Validación manual de respuesta (reemplaza Pydantic).
    Asegura que todos los campos cumplan límites y tipos correctos.
    """
    valid_types = ['success', 'no_results', 'error', 'text_fallback', 'parse_error', 'conversational']
    if 'answer_type' not in data or data['answer_type'] not in valid_types:
        data['answer_type'] = 'text_fallback'
    
    # Límites de strings
    if 'summary' in data and isinstance(data['summary'], str):
        data['summary'] = data['summary'][:500]
    
    if 'message' in data and isinstance(data['message'], str):
        data['message'] = data['message'][:2000]
    
    if 'html_table' in data and isinstance(data['html_table'], str):
        data['html_table'] = data['html_table'][:10000]
    
    if 'mermaid_diagram' in data and isinstance(data['mermaid_diagram'], str):
        data['mermaid_diagram'] = data['mermaid_diagram'][:5000]
    
    # Límites de listas
    if 'applications' in data and isinstance(data['applications'], list):
        data['applications'] = data['applications'][:20]
        for app in data['applications']:
            if 'highlights' in app and isinstance(app['highlights'], list):
                app['highlights'] = [str(h)[:200] for h in app['highlights'][:5]]
    
    if 'insights' in data and isinstance(data['insights'], list):
        data['insights'] = [str(i)[:200] for i in data['insights'][:10]]
    
    if 'suggestions' in data and isinstance(data['suggestions'], list):
        data['suggestions'] = [str(s)[:200] for s in data['suggestions'][:5]]
    
    # Timestamp
    if 'timestamp' not in data:
        data['timestamp'] = datetime.utcnow().isoformat()
    
    return data

# ==================== UTILIDADES ====================
def safe_json_parse(text: str) -> Optional[Dict]:
    """
    Extrae JSON de forma segura de texto que puede contener ruido.
    Usa regex para encontrar el bloque JSON principal.
    """
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        # Buscar JSON en el texto con regex
        match = re.search(r'\{(?:[^{}]|(?:\{[^{}]*\}))*\}', text, re.DOTALL)
        if match:
            try:
                return json.loads(match.group())
            except:
                pass
        return None

def sanitize_html(html: str) -> str:
    """
    Sanitiza HTML para evitar XSS.
    Permite solo tags seguros para tablas y remueve scripts/eventos.
    """
    if not html:
        return ""
    # Remover scripts
    html = re.sub(r'<script.*?</script>', '', html, flags=re.DOTALL | re.IGNORECASE)
    # Remover event handlers (onclick, onload, etc)
    html = re.sub(r'on\w+\s*=', '', html, flags=re.IGNORECASE)
    # Remover javascript: urls
    html = re.sub(r'javascript:', '', html, flags=re.IGNORECASE)
    return html

def sanitize_text(text: str, max_length: int = 1000) -> str:
    """
    Sanitiza texto normal removiendo caracteres peligrosos.
    """
    if not text:
        return ""
    # Remover caracteres HTML/JS potencialmente peligrosos
    text = re.sub(r'[<>\"\'`]', '', str(text))
    return text[:max_length].strip()

def validate_mermaid(code: str) -> bool:
    """
    Validación básica de sintaxis Mermaid.
    Verifica que contenga keywords válidos de diagramas.
    """
    if not code:
        return False
    keywords = ['graph', 'flowchart', 'sequenceDiagram', 'classDiagram', 'gantt', 'pie']
    return any(kw in code for kw in keywords)

# ==================== ROUTING INTELIGENTE ====================
def needs_rag_search(question: str) -> bool:
    """
    Detecta si la pregunta NECESITA buscar en OpenSearch.
    
    Returns:
        True: Necesita búsqueda RAG (tiene keywords de datos)
        False: Conversacional (saludo, ayuda, despedida)
    
    Estrategia:
        - Si contiene keywords de datos → RAG
        - Si es muy corta (≤3 palabras) sin keywords → Conversacional
    """
    question_lower = question.lower().strip()
    
    # Keywords que indican necesidad de datos
    data_keywords = [
        # Apps
        'aplicacion', 'aplicaciones', 'app', 'apps',
        'critica', 'crítica', 'criticidad', 'criticas', 'críticas',
        
        # Países
        'colombia', 'argentina', 'chile', 'perú', 'peru', 'méxico', 'mexico',
        'españa', 'espana', 'uruguay', 'venezuela', 'paraguay', 
        'turquía', 'turquia', 'estados unidos', 'usa', 'eeuu',
        
        # Atributos
        'deploy', 'drp', 'estrategica', 'estratégica',
        'activa', 'deprecada', 'mantenimiento', 'desarrollo',
        
        # Acciones
        'lista', 'listar', 'muestra', 'busca', 'encuentra',
        'cuantas', 'cuántas', 'donde', 'dónde', 'cual', 'cuál',
        
        # Tecnología
        'aws', 'azure', 'gcp', 'cloud', 'on-premise', 'kyndryl', 'ibm',
        
        # Específicos
        'portal', 'sistema', 'plataforma', 'servicio', 'atm', 'cajero'
    ]
    
    needs_data = any(keyword in question_lower for keyword in data_keywords)
    
    # Si es muy corto y sin keywords → conversacional
    if len(question_lower.split()) <= 3 and not needs_data:
        return False
    
    return needs_data

def generate_conversational_response(question: str) -> Dict:
    """
    Claude responde SIN búsqueda (para small talk, ayuda, etc).
    
    Casos de uso:
        - Saludos: "hola", "buenos días"
        - Ayuda: "ayuda", "¿cómo funciona?"
        - Despedidas: "gracias", "adiós"
        - Queries vagas: "apps" (sin contexto)
    """
    logger.info("Modo conversacional: Claude responde sin RAG")
    
    prompt = f"""Human: Eres un asistente amigable y profesional de aplicaciones BBVA.

**CONTEXTO**: El usuario hizo una pregunta que NO requiere buscar datos en la base de aplicaciones.

**INSTRUCCIONES**:
1. Responde de forma natural, profesional y útil
2. Si es saludo → Saluda y explica brevemente qué puedes hacer
3. Si pide ayuda → Explica cómo consultarte con ejemplos concretos
4. Si es despedida → Despídete amablemente
5. Si es vago → Pide más contexto específico con sugerencias útiles
6. Si pregunta qué eres → Explica que eres un sistema RAG de aplicaciones BBVA

**FORMATO DE RESPUESTA (JSON):**
{{
  "answer_type": "conversational",
  "message": "Tu respuesta conversacional aquí (usa \\n para saltos de línea)",
  "suggestions": ["Ejemplo de query 1", "Ejemplo 2", "Ejemplo 3"],
  "show_examples": true
}}

**EJEMPLOS DE RESPUESTAS:**

Pregunta: "hola"
{{
  "answer_type": "conversational",
  "message": "¡Hola! Soy tu asistente de aplicaciones BBVA.\\n\\nPuedo ayudarte con:\\n• Buscar aplicaciones por país o criticidad\\n• Generar tablas y diagramas visuales\\n• Consultar estado y arquitectura de apps",
  "suggestions": ["¿Qué aplicaciones críticas tiene Colombia?", "Muestra una tabla de apps en Argentina", "Lista aplicaciones con DRP activo"],
  "show_examples": true
}}

Pregunta: "gracias"
{{
  "answer_type": "conversational",
  "message": "¡De nada! Si necesitas consultar más aplicaciones, aquí estaré. ¡Hasta pronto!",
  "suggestions": [],
  "show_examples": false
}}

Pregunta: "apps"
{{
  "answer_type": "conversational",
  "message": "Necesito más contexto para ayudarte mejor. ¿Podrías especificar?\\n\\n• ¿De qué país?\\n• ¿Qué nivel de criticidad?\\n• ¿Algún filtro específico (deploy, DRP, estado)?",
  "suggestions": ["Apps críticas en Colombia", "Apps con DRP en Argentina", "Apps deprecadas que requieren atención"],
  "show_examples": false
}}

**PREGUNTA DEL USUARIO:**
<question>{sanitize_text(question)}</question>

Responde SOLO con el JSON (sin ```json ni texto adicional):"""

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1500,
        "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
        "temperature": 0.7  # Más creativo para conversación
    })
    
    try:
        response = bedrock_runtime.invoke_model(
            body=body,
            modelId=BEDROCK_GENERATION_MODEL_ID,
            accept="application/json",
            contentType="application/json"
        )
        
        response_body = json.loads(response.get('body').read())
        answer_text = response_body.get('content', [{}])[0].get('text', '')
        
        logger.info(f"Respuesta conversacional (primeros 200 chars): {answer_text[:200]}")
        
        parsed = safe_json_parse(answer_text)
        
        if parsed and parsed.get('answer_type') == 'conversational':
            return validate_response(parsed)
        else:
            # Fallback si parsing falla
            return validate_response({
                "answer_type": "conversational",
                "message": "¡Hola! Soy tu asistente de aplicaciones BBVA. Puedo ayudarte a consultar el portafolio de apps por país, criticidad, deploy, etc.\n\nPor ejemplo: '¿Qué aplicaciones críticas tiene Colombia?'",
                "suggestions": [
                    "¿Apps críticas en Colombia?",
                    "Muestra tabla de apps en Argentina",
                    "Apps con DRP activo"
                ],
                "show_examples": True
            })
            
    except Exception as e:
        logger.error(f"Error en conversational: {e}")
        return validate_response({
            "answer_type": "conversational",
            "message": "¡Hola! Soy tu asistente de aplicaciones BBVA. ¿En qué puedo ayudarte?\n\nPrueba preguntarme sobre aplicaciones por país, criticidad o estado.",
            "suggestions": [
                "¿Aplicaciones críticas en Colombia?",
                "Lista apps en Argentina",
                "Apps con DRP"
            ],
            "show_examples": True
        })

# ==================== EXTRACCIÓN DE FILTROS (V6: +exact_name +is_numerical) ====================
def extract_filters_from_question(question: str) -> Dict:
    """
    Detecta filtros, keywords visuales, nombres exactos y queries numéricas.
    
    V6 Cambios:
        + Detecta "qué es [nombre]" → exact_name
        + Detecta "cuántas/total" → is_numerical
    
    Returns:
        Dict con filtros detectados:
        - country: str
        - critic_name: str
        - status: str
        - deploy: str
        - has_drp: bool
        - is_strategic: bool
        - is_active: bool
        - exact_name: str (v6)
        - is_numerical: bool (v6)
        - visual_intent: dict (wants_table, wants_diagram, wants_comparison)
    """
    filters = {}
    question_lower = question.lower()
    
    logger.info(f"Extrayendo filtros de: '{question[:80]}'")
    
    # V6: Detectar nombre exacto (patrón: "qué es [nombre]")
    name_match = re.search(r'qu[ée]\s+es\s+(.+?)(?:\?|$)', question_lower)
    if name_match:
        exact_name_raw = name_match.group(1).strip()
        # Normaliza: Title case preservando acrónimos
        exact_name = ' '.join([
            word.upper() if word.isupper() or len(word) <= 3 else word.title() 
            for word in exact_name_raw.split()
        ])
        filters['exact_name'] = exact_name
        logger.info(f"Nombre exacto detectado: '{exact_name}'")
    
    # V6: Detectar intent numérico
    filters['is_numerical'] = any(word in question_lower for word in [
        'cuantas', 'cuántas', 'total', 'cuánto', 'how many', 'cantidad', 'numero', 'número'
    ])
    if filters['is_numerical']:
        logger.info("Intent numérico detectado")
    
    # Intención visual
    visual_intent = {
        'wants_table': any(word in question_lower for word in ['tabla', 'table', 'listar', 'list']),
        'wants_diagram': any(word in question_lower for word in ['diagrama', 'diagram', 'flow', 'flujo', 'grafico', 'chart']),
        'wants_comparison': any(word in question_lower for word in ['comparar', 'compare', 'vs', 'versus', 'diferencia'])
    }
    
    # Países (mapa de variaciones → nombre oficial)
    countries = {
        'colombia': 'Colombia',
        'perú': 'Perú', 'peru': 'Perú',
        'argentina': 'Argentina',
        'chile': 'Chile',
        'uruguay': 'Uruguay',
        'venezuela': 'Venezuela',
        'españa': 'España', 'espana': 'España',
        'méxico': 'México', 'mexico': 'México',
        'paraguay': 'Paraguay',
        'turquía': 'Turquía', 'turquia': 'Turquía',
        'estados unidos': 'Estados Unidos', 'usa': 'Estados Unidos', 'eeuu': 'Estados Unidos'
    }
    
    for key, value in countries.items():
        if key in question_lower:
            filters['country'] = value
            break
    
    # Criticidad (orden específico: muy crítico primero)
    if any(word in question_lower for word in ['muy critica', 'muy crítica', 'muy criticas', 'muy críticas']):
        filters['critic_name'] = 'Muy Crítico'
    elif any(word in question_lower for word in ['critica', 'crítica', 'criticas', 'críticas', 'criticidad']):
        filters['critic_name'] = 'Crítico'
    elif any(word in question_lower for word in ['media', 'medio']):
        filters['critic_name'] = 'Medio'
    elif any(word in question_lower for word in ['baja', 'bajo']):
        filters['critic_name'] = 'Bajo'
    
    # Status
    if any(word in question_lower for word in ['activa', 'activas', 'activo', 'activos', 'en uso']):
        filters['is_active'] = True
    elif any(word in question_lower for word in ['deprecada', 'deprecado', 'deprecadas']):
        filters['status'] = 'Deprecado'
    elif 'mantenimiento' in question_lower:
        filters['status'] = 'Mantenimiento'
    elif any(word in question_lower for word in ['desarrollo', 'en desarrollo']):
        filters['status'] = 'En Desarrollo'
    
    # DRP
    if 'drp' in question_lower or 'recuperación' in question_lower or 'recuperacion' in question_lower:
        filters['has_drp'] = True
    
    # Estratégico
    if any(word in question_lower for word in ['estratégica', 'estrategica', 'estratégicas', 'estrategico']):
        filters['is_strategic'] = True
    
    # Deploy (orden específico para evitar falsos positivos)
    if 'aws' in question_lower:
        filters['deploy'] = 'AWS'
    elif 'azure' in question_lower:
        filters['deploy'] = 'Azure'
    elif 'gcp' in question_lower or 'google cloud' in question_lower:
        filters['deploy'] = 'GCP'
    elif 'ibm' in question_lower:
        filters['deploy'] = 'IBM Cloud'
    elif 'kyndryl' in question_lower:
        filters['deploy'] = 'Kyndryl'
    elif 'hybrid' in question_lower or 'híbrido' in question_lower or 'hibrido' in question_lower:
        filters['deploy'] = 'Hybrid Cloud'
    elif 'on premise' in question_lower or 'on-premise' in question_lower:
        filters['deploy'] = 'On-Premise'
    
    filters['visual_intent'] = visual_intent
    logger.info(f"Filtros detectados: {filters}")
    return filters

# ==================== EMBEDDING ====================
def create_embedding(text: str) -> Optional[List[float]]:
    """
    Genera embedding usando Amazon Titan en Bedrock.
    
    Args:
        text: Texto a convertir en embedding
    
    Returns:
        Lista de floats (embedding vector) o None si falla
    """
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
        logger.error(f"Error creando embedding: {e}")
        return None

# ==================== BÚSQUEDA HÍBRIDA V6 (Exact + Aggs + KNN Optimizado) ====================
def search_opensearch(query_text: str, query_embedding: List[float], filters: Dict = None, top_k: int = TOP_K_RESULTS) -> Dict:
    """
    Búsqueda híbrida v6: BM25 + KNN + Exact Term + Aggregations.
    
    V6 Cambios:
        + Term query en metadata.name.keyword (boost 10.0) para exact match
        + Aggregations (size=0) para queries numéricas
        + KNN k aumentado a top_k * 3 (45) para mejor cobertura
    
    Estrategia de 6 métodos combinados:
        1. Term exacto en name.keyword (boost 10.0) - SI exact_name detectado
        2. KNN semántico (k=45) - Encuentra conceptos similares
        3. BM25 en metadata.name (boost 5.0) - Nombres fuzzy
        4. BM25 en text_content (boost 2.0) - Descripciones
        5. Phrase match (boost 3.0) - Frases exactas
        6. Multi-match (boost 1.5) - Búsqueda en múltiples campos
    
    Aggregations:
        - total_apps: cardinality en id_app (apps únicas, no docs)
        - by_country: terms agg (si no numérico)
    
    Args:
        query_text: Texto original de la pregunta
        query_embedding: Vector embedding de la pregunta
        filters: Filtros detectados (país, criticidad, exact_name, is_numerical, etc)
        top_k: Número máximo de resultados
    
    Returns:
        Dict con 'total', 'results', 'has_more', 'aggregations'
    """
    logger.info(f"Búsqueda híbrida v6 - Query: '{query_text[:80]}'")
    
    # Extraer flags especiales antes de construir query
    is_numerical = filters.get('is_numerical', False) if filters else False
    exact_name = filters.pop('exact_name', None) if filters else None
    visual_intent = filters.pop('visual_intent', None) if filters else None
    
    # Construir should clauses (métodos de búsqueda)
    should_clauses = []
    
    # V6: 1. Term exacto (MÁXIMA PRIORIDAD si exact_name detectado)
    if exact_name:
        should_clauses.append({
            "term": {
                "metadata.name": {  # Campo keyword directo (sin .keyword)
                    "value": exact_name,
                    "boost": 10.0  # Boost alto de investigación
                }
            }
        })
        logger.info(f"Búsqueda exacta por nombre: '{exact_name}' (boost 10.0)")
    
    # V6: 2. KNN Semántico (k aumentado a top_k * 3 = 45)
    should_clauses.append({
        "knn": {
            "embedding": {
                "vector": query_embedding,
                "k": top_k * 3  # V6: De 30 a 45 para mejor cobertura
            }
        }
    })
    
    # 3. BM25 en metadata.name (nombres fuzzy)
    should_clauses.append({
        "match": {
            "metadata.name": {
                "query": query_text,
                "boost": 5.0
            }
        }
    })
    
    # 4. BM25 en text_content
    should_clauses.append({
        "match": {
            "text_content": {
                "query": query_text,
                "boost": 2.0
            }
        }
    })
    
    # 5. Phrase match
    should_clauses.append({
        "match_phrase": {
            "text_content": {
                "query": query_text,
                "boost": 3.0
            }
        }
    })
    
    # 6. Multi-match
    should_clauses.append({
        "multi_match": {
            "query": query_text,
            "fields": ["metadata.name^3", "text_content^1", "metadata.owner^1"],
            "type": "best_fields",
            "boost": 1.5
        }
    })
    
    # V6: Size = 0 para queries numéricas (solo aggregations)
    search_body = {
        "size": 0 if is_numerical else top_k,
        "query": {
            "bool": {
                "should": should_clauses,
                "minimum_should_match": 1
            }
        },
        "_source": ["text_content", "metadata"]
    }
    
    # Aplicar filtros adicionales (country, criticidad, etc)
    if filters:
        filter_clauses = []
        
        for key, value in filters.items():
            if key in ['country', 'status', 'critic_name', 'deploy', 'app_type', 'quadrant']:
                filter_clauses.append({"term": {f"metadata.{key}": value}})
            elif key in ['is_strategic', 'has_drp', 'is_active']:
                filter_clauses.append({"term": {f"metadata.{key}": value}})
        
        if filter_clauses:
            search_body["query"]["bool"]["filter"] = filter_clauses
            logger.info(f"Filtros aplicados: {[f['term'] for f in filter_clauses]}")
    
    # V6: Aggregations (para counts precisos)
    aggs = {
        "total_apps": {
            "cardinality": {"field": "metadata.id_app"}  # Estima apps únicas por ID
        }
    }
    
    # Agg adicional por country (si no es numérico)
    if not is_numerical and filters and 'country' not in filters:
        aggs['by_country'] = {
            "terms": {
                "field": "metadata.country.keyword",
                "size": 10
            }
        }
    
    search_body["aggs"] = aggs
    
    try:
        response = opensearch_client.search(index=OPENSEARCH_INDEX, body=search_body)
        
        # Parsear resultados
        results = []
        if not is_numerical:  # Solo procesar hits si no es numérico
            for hit in response['hits']['hits']:
                results.append({
                    'score': hit['_score'],
                    'text': hit['_source']['text_content'],
                    'metadata': hit['_source']['metadata']
                })
        
        # V6: Total preciso de aggregations
        total_hits = response['hits']['total']['value']
        agg_total = response.get('aggregations', {}).get('total_apps', {}).get('value', total_hits)
        
        # 📊 Log top 3 resultados para debugging (si no es numérico)
        if results:
            logger.info(f"Top 3 resultados:")
            for idx, result in enumerate(results[:3], 1):
                app_name = result['metadata'].get('name', 'N/A')[:50]
                score = result['score']
                logger.info(f"  {idx}. {app_name} (score: {score:.2f})")
        
        logger.info(f"Híbrido v6: {agg_total} totales, retornando top {len(results)}")
        
        # Restaurar visual_intent si existía
        if visual_intent and filters is not None:
            filters['visual_intent'] = visual_intent
        
        return {
            'total': agg_total,  # V6: Usa agg count
            'results': results,
            'has_more': False if is_numerical else agg_total > len(results),
            'aggregations': response.get('aggregations', {})  # V6: Pasa aggs completas
        }
    except Exception as e:
        logger.error(f"Error en búsqueda híbrida v6: {e}")
        return {'total': 0, 'results': [], 'has_more': False, 'aggregations': {}}

# ==================== GENERACIÓN DE RESPUESTA V6 (Soporte Numérico) ====================
def generate_response(question: str, search_results: Dict, applied_filters: Dict) -> Dict:
    """
    Genera respuesta estructurada con Claude.
    
    V6 Cambios:
        + Maneja queries numéricas (retorna count sin listar apps)
        + Usa total de aggregations
    
    Soporta visuales: HTML tables, Mermaid diagrams, Chart.js data.
    
    Args:
        question: Pregunta original del usuario
        search_results: Resultados de OpenSearch (v6: incluye aggregations)
        applied_filters: Filtros aplicados en la búsqueda
    
    Returns:
        Dict con respuesta estructurada validada
    """
    logger.info("Generando respuesta con Claude (v6)...")
    
    # V6: Manejo de queries numéricas (sin resultados detallados)
    is_numerical = applied_filters.get('is_numerical', False)
    if is_numerical:
        count = search_results['total']
        logger.info(f"Query numérica: Retornando count={count}")
        
        # Construir mensaje según filtros
        filters_text = []
        if 'country' in applied_filters:
            filters_text.append(f"en {applied_filters['country']}")
        if 'critic_name' in applied_filters:
            filters_text.append(f"con criticidad {applied_filters['critic_name']}")
        if 'deploy' in applied_filters:
            filters_text.append(f"desplegadas en {applied_filters['deploy']}")
        if 'has_drp' in applied_filters:
            filters_text.append("con DRP activo")
        
        context_text = " ".join(filters_text) if filters_text else "en total"
        
        return validate_response({
            "answer_type": "success",
            "summary": f"Encontré {count} aplicaciones {context_text}.",
            "total_found": count,
            "applications": [],  # No lista apps para counts
            "insights": [
                f"Total preciso: {count} aplicaciones {context_text}",
                "Para ver detalles, pregunta específicamente por país, criticidad o nombre"
            ],
            "filters_applied": {k:v for k,v in applied_filters.items() if k not in ['visual_intent', 'is_numerical']},
            "has_more": False,
            "page": 1,
            "page_size": 0
        })
    
    # Manejo estándar (no numérico)
    if not search_results['results']:
        return validate_response({
            "answer_type": "no_results",
            "message": "No encontré información relevante para tu consulta.",
            "suggestions": [
                "Verifica que el país esté bien escrito",
                "Intenta: '¿Apps críticas en Colombia?'",
                "Prueba: 'Muestra tabla de apps en Argentina'"
            ],
            "filters_applied": {k:v for k,v in applied_filters.items() if k not in ['visual_intent', 'is_numerical']}
        })
    
    # Construir contexto para Claude
    context_parts = []
    total_results = len(search_results['results'])
    display_limit = min(total_results, TOP_K_RESULTS)
    
    for idx, result in enumerate(search_results['results'][:display_limit], 1):
        metadata = result['metadata']
        context_parts.append(f"""
Aplicación {idx}:
- Nombre: {metadata.get('name', 'N/A')}
- País: {metadata.get('country', 'N/A')}
- Criticidad: {metadata.get('critic_name', 'N/A')} (Score: {metadata.get('score', 'N/A')})
- Tipo: {metadata.get('app_type', 'N/A')}
- Deploy: {metadata.get('deploy', 'N/A')}
- Status: {metadata.get('status', 'N/A')}
- DRP: {metadata.get('drp', 'N/A')}
- Estratégico: {'Sí' if metadata.get('is_strategic') else 'No'}
- Owner: {metadata.get('owner', 'N/A')}
- Dominio: {metadata.get('service_domain', 'N/A')}
""")
    
    context = "\n---\n".join(context_parts)
    
    # Detectar intención visual
    visual_intent = applied_filters.get('visual_intent', {})
    wants_table = visual_intent.get('wants_table', False)
    wants_diagram = visual_intent.get('wants_diagram', False)
    
    prompt = f"""Human: Eres un asistente experto en arquitectura BBVA.

**INSTRUCCIONES CRÍTICAS:**
1. Analiza TODOS los resultados del contexto cuidadosamente
2. Si la pregunta busca una app específica por nombre, identifícala en el contexto
3. Responde en JSON VÁLIDO con esta estructura EXACTA:

{{
  "answer_type": "success",
  "summary": "Resumen breve y preciso en 1-2 líneas",
  "total_found": {search_results['total']},
  "applications": [
    {{
      "name": "Nombre exacto de la aplicación",
      "country": "País",
      "criticality": "Nivel de criticidad",
      "status": "Estado actual",
      "deploy": "Plataforma de deploy",
      "score": 85.5,
      "highlights": ["Dato clave 1", "Dato clave 2"]
    }}
  ],
  "insights": ["Observación técnica relevante 1", "Observación 2"],
  "filters_applied": {json.dumps({k:v for k,v in applied_filters.items() if k not in ['visual_intent', 'is_numerical']})},
  "has_more": {str(search_results.get('has_more', False)).lower()},
  "page": 1,
  "page_size": {display_limit}
}}

**SI LA PREGUNTA PIDE TABLA** (detectado: {wants_table}), AÑADE este campo:
   "html_table": "<table border='1' style='width:100%; border-collapse:collapse;'><thead><tr style='background:#002d72; color:white;'><th>Nombre</th><th>País</th><th>Criticidad</th><th>Deploy</th><th>Estado</th></tr></thead><tbody><tr><td>App1</td><td>Colombia</td><td>Crítico</td><td>AWS</td><td>Activo</td></tr></tbody></table>"

**SI LA PREGUNTA PIDE DIAGRAMA** (detectado: {wants_diagram}), AÑADE este campo:
   "mermaid_diagram": "flowchart TD\\n    A[Query Usuario] --> B[Embedding]\\n    B --> C[OpenSearch Híbrido]\\n    C --> D[Claude Generation]\\n    D --> E[Respuesta]\\n    style A fill:#e3f2fd,stroke:#002d72\\n    style E fill:#c8e6c9,stroke:#388e3c"

**IMPORTANTE**: 
- Si el contexto contiene apps relacionadas aunque no sea el nombre exacto, menciónalas
- Usa tu criterio para identificar la app más relevante
- Prioriza calidad sobre cantidad en highlights e insights
- RESPONDE SOLO CON EL JSON (sin ```json ni texto adicional)

**CONTEXTO DE APLICACIONES:**
<context>
{context}
</context>

**PREGUNTA DEL USUARIO:**
<question>{sanitize_text(question)}</question>

Genera el JSON completo ahora:"""

    body = json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": MAX_TOKENS,
        "messages": [{"role": "user", "content": [{"type": "text", "text": prompt}]}],
        "temperature": 0.3  # Más determinístico para datos estructurados
    })
    
    try:
        response = bedrock_runtime.invoke_model(
            body=body,
            modelId=BEDROCK_GENERATION_MODEL_ID,
            accept="application/json",
            contentType="application/json"
        )
        
        response_body = json.loads(response.get('body').read())
        answer_text = response_body.get('content', [{}])[0].get('text', '')
        
        logger.info(f"Respuesta Claude (primeros 300 chars): {answer_text[:300]}")
        
        # Parsing seguro del JSON
        parsed_json = safe_json_parse(answer_text)
        
        if not parsed_json:
            logger.warning("JSON parsing falló")
            return validate_response({
                "answer_type": "parse_error",
                "message": "La respuesta no pudo ser procesada completamente.",
                "raw_text": answer_text[:500]
            })
        
        # Sanitizar visuales (XSS protection)
        if 'html_table' in parsed_json and parsed_json['html_table']:
            parsed_json['html_table'] = sanitize_html(parsed_json['html_table'])
            logger.info("HTML table sanitizada")
        
        if 'mermaid_diagram' in parsed_json and parsed_json['mermaid_diagram']:
            if not validate_mermaid(parsed_json['mermaid_diagram']):
                logger.warning("Mermaid diagram inválido, removiendo")
                parsed_json['mermaid_diagram'] = None
            else:
                logger.info("Mermaid diagram válido")
        
        return validate_response(parsed_json)
        
    except Exception as e:
        logger.error(f"Error generando respuesta: {e}")
        return validate_response({
            "answer_type": "error",
            "message": f"Error al generar respuesta: {str(e)}"
        })

# ==================== HANDLER PRINCIPAL ====================
def handler(event, context):
    """
    Handler principal de Lambda v6 con exact matching y aggregations.
    
    V6 Flow:
        1. Validar input
        2. Routing: ¿Conversacional o RAG?
        3. Si conversacional → Claude responde directo
        4. Si RAG:
           a. Extraer filtros (detect exact_name, is_numerical)
           b. Embedding
           c. Búsqueda Híbrida v6 (Term + BM25 + KNN + Aggs)
           d. Generate response (con soporte numérico)
        5. Retornar respuesta estructurada
    
    Args:
        event: API Gateway event con body.question
        context: Lambda context
    
    Returns:
        HTTP response con JSON estructurado
    """
    request_id = context.aws_request_id if context else "local"
    logger.info(f"{'='*60}")
    logger.info(f"[{request_id}] INICIANDO QUERY (v6)")
    logger.info(f"{'='*60}")
    
    try:
        # Parsear body
        body = json.loads(event.get('body', '{}'))
        question = body.get('question', '').strip()
        
        # Guardar endpoint en S3
        endpoint_json = f'endpoints/{ALUMNO_ID}.json'
        s3.put_object(
            Bucket=BUCKET,
            Key=endpoint_json,
            Body=json.dumps({
                "nombre-apellido": ALUMNO_ID,
                "endpoint": API_GATEWAY_ENDPOINT
            }, indent=2),
            ContentType='application/json'
        )
        # Validar input
        if not question:
            logger.warning("Solicitud sin pregunta")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS'
                },
                'body': json.dumps({
                    'error': 'El campo "question" es requerido'
                })
            }
        
        # Sanitizar input
        question = sanitize_text(question, max_length=500)
        logger.info(f"Pregunta: '{question}'")
        
        # ========== ROUTING INTELIGENTE ==========
        if not needs_rag_search(question):
            logger.info(f"[{request_id}] → CONVERSACIONAL (sin búsqueda)")
            conversational_response = generate_conversational_response(question)
            
            return {
                'statusCode': 200,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS'
                },
                'body': json.dumps(conversational_response, ensure_ascii=False)
            }
        
        # ========== RUTA RAG V6 (Exact + Aggs + Híbrido) ==========
        logger.info(f"[{request_id}] → RAG v6 (exact + aggs + híbrido)")
        
        # 1. Extraer filtros (v6: incluye exact_name, is_numerical)
        filters = extract_filters_from_question(question)
        
        # 2. Crear embedding
        query_embedding = create_embedding(question)
        if not query_embedding:
            logger.error("Falló creación de embedding")
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
                'body': json.dumps(validate_response({
                    'answer_type': 'error',
                    'message': 'Error al procesar la pregunta (embedding failed)'
                }))
            }
        
        # 3. Búsqueda híbrida v6 (Term + BM25 + KNN + Aggs)
        search_results = search_opensearch(question, query_embedding, filters)
        
        # 4. Generar respuesta con Claude (v6: soporte numérico)
        structured_answer = generate_response(question, search_results, filters)
        
        logger.info(f"[{request_id}] Respuesta v6: {structured_answer.get('answer_type')}")
        logger.info(f"{'='*60}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            },
            'body': json.dumps(structured_answer, ensure_ascii=False)
        }
        
    except Exception as e:
        logger.error(f"Error inesperado: {e}", exc_info=True)
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
            'body': json.dumps(validate_response({
                'answer_type': 'error',
                'message': 'Error interno del servidor'
            }))
        }

# ==================== FIN DEL CÓDIGO V6 ====================