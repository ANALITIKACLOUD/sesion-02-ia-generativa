# lambda_function_csv.py
# Versión optimizada para embeddings de aplicaciones - VARIABILIZADA
 
import boto3
import pandas as pd
import json
import os
from io import StringIO
from opensearchpy import OpenSearch, RequestsHttpConnection, AWSV4SignerAuth
from opensearchpy.helpers import bulk
from opensearchpy.exceptions import NotFoundError
import re
from typing import Dict, List, Optional, Tuple
 
# --- 1. CONFIGURACIÓN DESDE VARIABLES DE ENTORNO ---
 
# OpenSearch
OPENSEARCH_HOST = os.environ.get('OPENSEARCH_ENDPOINT', '')
OPENSEARCH_INDEX = os.environ.get('OPENSEARCH_INDEX', '')
OPENSEARCH_PORT = int(os.environ.get('OPENSEARCH_PORT', '443'))
OPENSEARCH_SERVICE = os.environ.get('OPENSEARCH_SERVICE', 'es')  # 'es' para VPC, 'aoss' para Serverless
 
# AWS
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
 
# Bedrock
BEDROCK_EMBEDDING_MODEL_ID = os.environ.get('BEDROCK_MODEL_ID', 'amazon.titan-embed-text-v1')
EMBEDDING_DIMENSION = int(os.environ.get('EMBEDDING_DIMENSION', '1536'))
 
# S3 Source (defaults para testing)
DEFAULT_S3_BUCKET = os.environ.get('S3_BUCKET', '')
DEFAULT_S3_KEY = os.environ.get('S3_KEY', 'bbva_applications.csv')
 
# Chunks
MAX_CHUNK_SIZE = int(os.environ.get('MAX_CHUNK_SIZE', '500'))
MIN_CHUNK_SIZE = int(os.environ.get('MIN_CHUNK_SIZE', '50'))
 
# Performance
BATCH_SIZE = int(os.environ.get('BATCH_SIZE', '100'))
OPENSEARCH_POOL_SIZE = int(os.environ.get('OPENSEARCH_POOL_SIZE', '20'))
OPENSEARCH_TIMEOUT = int(os.environ.get('OPENSEARCH_TIMEOUT', '30'))
 
# Índice
INDEX_SHARDS = int(os.environ.get('INDEX_SHARDS', '1'))
INDEX_REPLICAS = int(os.environ.get('INDEX_REPLICAS', '0'))
KNN_EF_SEARCH = int(os.environ.get('KNN_EF_SEARCH', '100'))
 
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
 
# --- 3. FUNCIONES DE PROCESAMIENTO DE TEXTO ---
def clean_text(text: str) -> str:
    """Limpia y normaliza texto para embedding."""
    if pd.isna(text) or not text:
        return ""
    text = re.sub(r'\s+', ' ', str(text).strip())
    text = re.sub(r'[^\w\s\.\,\;\:\!\?\-\(\)]', ' ', text)
    return text
 
def create_enriched_text(row: pd.Series) -> str:
    """Crea texto enriquecido con contexto para embedding de aplicaciones."""
    id_app = clean_text(row.get('Id_App', ''))
    country = clean_text(row.get('Country', ''))
    name = clean_text(row.get('Name', ''))
    critic_name = clean_text(row.get('Critic Name', ''))
    estrategic = clean_text(row.get('Estrategic', ''))
    critic_info = clean_text(row.get('Critic Info', ''))
    score = clean_text(row.get('Score', ''))
    classif_type = clean_text(row.get('ClassifType', ''))
    app_type = clean_text(row.get('AppType', ''))
    deploy = clean_text(row.get('Deploy', ''))
    status = clean_text(row.get('Status', ''))
    service_domain = clean_text(row.get('ServiceDomain', ''))
    quadrant = clean_text(row.get('Quadrant', ''))
    product_domain = clean_text(row.get('ProductDomain', ''))
    specialist = clean_text(row.get('Specialist', ''))
    architect_app = clean_text(row.get('Architect App', ''))
    owner = clean_text(row.get('Owner', ''))
    description = clean_text(row.get('Description', ''))
    rto = clean_text(row.get('RTO', ''))
    drp = clean_text(row.get('DRP', ''))
    starting_year = clean_text(row.get('Starting Year', ''))
 
    base_text = f"[{country}] {name}"
   
    if id_app:
        base_text += f" (ID: {id_app})"
 
    criticality_info = []
    if critic_name:
        criticality_info.append(f"Criticidad: {critic_name}")
    if score:
        criticality_info.append(f"Score: {score}")
    if estrategic:
        criticality_info.append(f"Estratégico: {estrategic}")
    if criticality_info:
        base_text += f" | {' | '.join(criticality_info)}"
 
    type_info = []
    if classif_type:
        type_info.append(f"Clasificación: {classif_type}")
    if app_type:
        type_info.append(f"Tipo: {app_type}")
    if quadrant:
        type_info.append(f"Cuadrante: {quadrant}")
    if type_info:
        base_text += f" | {' | '.join(type_info)}"
 
    deploy_info = []
    if deploy:
        deploy_info.append(f"Deploy: {deploy}")
    if status:
        deploy_info.append(f"Estado: {status}")
    if drp:
        deploy_info.append(f"DRP: {drp}")
    if rto:
        deploy_info.append(f"RTO: {rto}")
    if deploy_info:
        base_text += f" | {' | '.join(deploy_info)}"
 
    domain_info = []
    if service_domain:
        domain_info.append(f"Dominio Servicio: {service_domain}")
    if product_domain:
        domain_info.append(f"Dominio Producto: {product_domain}")
    if specialist:
        domain_info.append(f"Especialista: {specialist}")
    if architect_app:
        domain_info.append(f"Arquitecto: {architect_app}")
    if owner:
        domain_info.append(f"Owner: {owner}")
    if domain_info:
        base_text += f" | {' | '.join(domain_info)}"
 
    additional_info = []
    if starting_year:
        additional_info.append(f"Año inicio: {starting_year}")
    if critic_info:
        additional_info.append(f"Info crítica: {critic_info}")
    if description:
        additional_info.append(f"Descripción: {description}")
    if additional_info:
        base_text += f" | {' | '.join(additional_info)}"
 
    return base_text
 
def create_chunks(text: str, metadata: Dict) -> List[Tuple[str, Dict]]:
    """Divide texto largo en chunks manteniendo contexto."""
    if len(text) <= MAX_CHUNK_SIZE:
        return [(text, metadata)]
 
    chunks = []
    sentences = re.split(r'[.!?]+', text)
    current_chunk = ""
    chunk_num = 0
 
    context_prefix = ""
    if ':' in text:
        context_prefix = text.split(':', 1)[0] + ": "
 
    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
 
        potential_chunk = current_chunk + sentence + ". "
 
        if len(potential_chunk) > MAX_CHUNK_SIZE and len(current_chunk) > MIN_CHUNK_SIZE:
            chunk_metadata = metadata.copy()
            chunk_metadata['chunk_number'] = chunk_num
            chunk_metadata['total_chunks'] = 0
            chunks.append((current_chunk.strip(), chunk_metadata))
 
            current_chunk = context_prefix + sentence + ". "
            chunk_num += 1
        else:
            current_chunk = potential_chunk
 
    if len(current_chunk.strip()) > MIN_CHUNK_SIZE:
        chunk_metadata = metadata.copy()
        chunk_metadata['chunk_number'] = chunk_num
        chunks.append((current_chunk.strip(), chunk_metadata))
 
    for _, chunk_metadata in chunks:
        chunk_metadata['total_chunks'] = len(chunks)
 
    return chunks
 
def create_metadata(row: pd.Series, chunk_info: Optional[Dict] = None) -> Dict:
    """Crea metadatos estructurados para el documento."""
    def clean_value(value, default=""):
        return default if pd.isna(value) else value
 
    def clean_numeric(value, default=0):
        try:
            return float(value) if not pd.isna(value) else default
        except:
            return default
 
    def clean_int(value, default=0):
        try:
            return int(value) if not pd.isna(value) else default
        except:
            return default
 
    metadata = {
        'id_app': clean_value(row.get('Id_App')),
        'country': clean_value(row.get('Country')),
        'name': clean_value(row.get('Name')),
        'critic_name': clean_value(row.get('Critic Name')),
        'estrategic': clean_value(row.get('Estrategic')),
        'critic_info': clean_value(row.get('Critic Info')),
        'score': clean_numeric(row.get('Score')),
        'classif_type': clean_value(row.get('ClassifType')),
        'app_type': clean_value(row.get('AppType')),
        'deploy': clean_value(row.get('Deploy')),
        'status': clean_value(row.get('Status')),
        'service_domain': clean_value(row.get('ServiceDomain')),
        'quadrant': clean_value(row.get('Quadrant')),
        'product_domain': clean_value(row.get('ProductDomain')),
        'specialist': clean_value(row.get('Specialist')),
        'architect_app': clean_value(row.get('Architect App')),
        'owner': clean_value(row.get('Owner')),
        'description': clean_value(row.get('Description')),
        'rto': clean_value(row.get('RTO')),
        'drp': clean_value(row.get('DRP')),
        'starting_year': clean_int(row.get('Starting Year')),
 
        'is_strategic': clean_value(row.get('Estrategic', '')).upper() == 'SI',
        'has_drp': bool(clean_value(row.get('DRP'))),
        'is_active': clean_value(row.get('Status', '')).lower() in ['activo', 'active', 'en uso'],
       
        'is_chunked': False,
        'processed_timestamp': pd.Timestamp.now().isoformat()
    }
 
    if chunk_info:
        metadata.update(chunk_info)
        metadata['is_chunked'] = True
 
    return metadata
 
# --- 4. FUNCIONES DE EMBEDDING ---
def create_embedding(text: str) -> List[float]:
    """Crea embedding usando Amazon Bedrock."""
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
 
def process_csv_data(bucket: str, key: str) -> List[Dict]:
    """Procesa datos del CSV y crea documentos para indexar."""
    s3_client = boto3.client('s3', region_name=AWS_REGION)
    obj = s3_client.get_object(Bucket=bucket, Key=key)
   
    csv_content = obj['Body'].read().decode('utf-8')
    df = pd.read_csv(StringIO(csv_content))
 
    documents = []
    processed_count = 0
    skipped_count = 0
 
    print(f"Procesando {len(df)} registros del CSV...")
 
    for index, row in df.iterrows():
        try:
            enriched_text = create_enriched_text(row)
 
            if not enriched_text or len(enriched_text.strip()) < 10:
                skipped_count += 1
                continue
 
            base_metadata = create_metadata(row)
            chunks = create_chunks(enriched_text, base_metadata)
 
            for chunk_text, chunk_metadata in chunks:
                embedding = create_embedding(chunk_text)
 
                if embedding:
                    document = {
                        "_index": OPENSEARCH_INDEX,
                        "_source": {
                            "text_content": chunk_text,
                            "embedding": embedding,
                            "metadata": chunk_metadata,
                            "original_row_index": index
                        }
                    }
                    documents.append(document)
                    processed_count += 1
                else:
                    print(f"Error creando embedding para fila {index}")
 
        except Exception as e:
            print(f"Error procesando fila {index}: {e}")
            skipped_count += 1
 
    print(f"Procesamiento completado: {processed_count} documentos creados, {skipped_count} registros omitidos")
    return documents
 
# --- 5. FUNCIONES DE OPENSEARCH ---
def create_opensearch_index():
    """Crea índice optimizado en OpenSearch."""
    if opensearch_client.indices.exists(index=OPENSEARCH_INDEX):
        print(f"El índice '{OPENSEARCH_INDEX}' ya existe.")
        return True
 
    print(f"Creando índice optimizado '{OPENSEARCH_INDEX}' en OpenSearch...")
 
    settings = {
        "settings": {
            "index": {
                "knn": True,
                "knn.algo_param.ef_search": KNN_EF_SEARCH,
                "number_of_shards": INDEX_SHARDS,
                "number_of_replicas": INDEX_REPLICAS
            }
        },
        "mappings": {
            "properties": {
                "embedding": {
                    "type": "knn_vector",
                    "dimension": EMBEDDING_DIMENSION,
                    "method": {
                        "name": "hnsw",
                        "space_type": "l2",
                        "engine": "faiss"
                    }
                },
                "text_content": {
                    "type": "text",
                    "analyzer": "standard"
                },
                "metadata": {
                    "properties": {
                        "id_app": {"type": "keyword"},
                        "country": {"type": "keyword"},
                        "name": {"type": "keyword"},
                        "critic_name": {"type": "keyword"},
                        "estrategic": {"type": "keyword"},
                        "critic_info": {"type": "text"},
                        "score": {"type": "float"},
                        "classif_type": {"type": "keyword"},
                        "app_type": {"type": "keyword"},
                        "deploy": {"type": "keyword"},
                        "status": {"type": "keyword"},
                        "service_domain": {"type": "keyword"},
                        "quadrant": {"type": "keyword"},
                        "product_domain": {"type": "keyword"},
                        "specialist": {"type": "keyword"},
                        "architect_app": {"type": "keyword"},
                        "owner": {"type": "keyword"},
                        "description": {"type": "text"},
                        "rto": {"type": "keyword"},
                        "drp": {"type": "keyword"},
                        "starting_year": {"type": "integer"},
 
                        "is_strategic": {"type": "boolean"},
                        "has_drp": {"type": "boolean"},
                        "is_active": {"type": "boolean"},
 
                        "is_chunked": {"type": "boolean"},
                        "processed_timestamp": {"type": "date"},
                        "chunk_number": {"type": "integer"},
                        "total_chunks": {"type": "integer"}
                    }
                },
                "original_row_index": {"type": "integer"}
            }
        }
    }
 
    opensearch_client.indices.create(index=OPENSEARCH_INDEX, body=settings)
    print("Índice creado exitosamente.")
    return False
 
# --- 6. FUNCIÓN PRINCIPAL DE LAMBDA ---
def handler(event, context):
    """Función principal optimizada de Lambda para CSV."""
    print(f"Iniciando procesamiento - Región: {AWS_REGION}, Índice: {OPENSEARCH_INDEX}")
 
    try:
        # Usar valores por defecto o evento S3
        s3_bucket = DEFAULT_S3_BUCKET
        s3_key = DEFAULT_S3_KEY
        # Evento S3 (trigger automático)
        if not s3_bucket or not s3_key:
            if 'Records' in event and len(event['Records']) > 0:
                s3_bucket = event['Records'][0]['s3']['bucket']['name']
                s3_key = event['Records'][0]['s3']['object']['key']
            else:
                return {
                    'statusCode': 400,
                    'body': json.dumps('Configurar S3_BUCKET y S3_KEY en variables de entorno o enviar evento S3.')
                }
       
        print(f"Archivo detectado: s3://{s3_bucket}/{s3_key}")
 
        # Verificar que sea un archivo CSV
        if not s3_key.lower().endswith('.csv'):
            print(f"Archivo {s3_key} no es un CSV. Omitiendo.")
            return {
                'statusCode': 200,
                'body': json.dumps('Archivo no soportado.')
            }
 
        # Crear o verificar índice
        index_existed = create_opensearch_index()
 
        # Limpiar índice si ya existía
        if index_existed:
            print(f"Limpiando documentos existentes del índice '{OPENSEARCH_INDEX}'...")
            try:
                opensearch_client.delete_by_query(
                    index=OPENSEARCH_INDEX,
                    body={"query": {"match_all": {}}}
                )
                print("Documentos anteriores eliminados.")
            except NotFoundError:
                print("No se encontraron documentos para eliminar.")
            except Exception as e:
                print(f"Error limpiando índice: {e}")
 
        # Procesar datos y crear documentos
        documents = process_csv_data(s3_bucket, s3_key)
 
        if not documents:
            return {
                'statusCode': 400,
                'body': json.dumps('No se pudieron procesar documentos del archivo.')
            }
 
        print(f"Indexando {len(documents)} documentos en lotes de {BATCH_SIZE}...")
        success, failed = bulk(opensearch_client, documents, chunk_size=BATCH_SIZE)
 
        print(f"Indexación completada. Éxito: {success}, Fallos: {len(failed) if failed else 0}")
 
        if failed:
            print("Fallos detectados durante la indexación:")
            for i, fail_reason in enumerate(failed[:5]):
                print(f"Fallo {i+1}: {fail_reason}")
 
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Procesamiento de aplicaciones completado exitosamente',
                'documents_processed': len(documents),
                'documents_indexed': success,
                'documents_failed': len(failed) if failed else 0,
                'index_name': OPENSEARCH_INDEX,
                's3_source': f's3://{s3_bucket}/{s3_key}'
            })
        }
 
    except Exception as e:
        print(f"Error en lambda_handler: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error procesando archivo: {str(e)}')
        }