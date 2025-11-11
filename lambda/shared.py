"""
Módulo compartido para Lambdas del Taller RAG
Configuración de clientes AWS y funciones comunes
"""

import json
import boto3
import os
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth

# Configuración de clientes AWS
s3_client = boto3.client('s3')
bedrock_client = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))

# Configuración de OpenSearch
region = os.environ.get('AWS_REGION', 'us-east-1')
service = 'es'
credentials = boto3.Session().get_credentials()
awsauth = AWS4Auth(
    credentials.access_key,
    credentials.secret_key,
    region,
    service,
    session_token=credentials.token
)

opensearch_client = OpenSearch(
    hosts=[{'host': os.environ['OPENSEARCH_ENDPOINT'], 'port': 443}],
    http_auth=awsauth,
    use_ssl=True,
    verify_certs=True,
    connection_class=RequestsHttpConnection,
    timeout=30
)


def generate_embedding(text):
    """
    Generar embedding usando Bedrock Titan Embeddings
    """
    try:
        model_id = os.environ.get('BEDROCK_MODEL_ID', 'amazon.titan-embed-text-v1')
        
        # Preparar payload
        body = json.dumps({"inputText": text})
        
        # Invocar modelo
        response = bedrock_client.invoke_model(
            modelId=model_id,
            body=body
        )
        
        # Parsear respuesta
        response_body = json.loads(response['body'].read())
        embedding = response_body['embedding']
        
        print(f"Generated embedding with {len(embedding)} dimensions")
        
        return embedding
    
    except Exception as e:
        print(f"Error generating embedding: {str(e)}")
        raise


def create_index_if_not_exists(index_name):
    """
    Crear índice de OpenSearch con configuración KNN si no existe
    """
    if opensearch_client.indices.exists(index=index_name):
        print(f"Index {index_name} already exists")
        return
    
    print(f"Creating index: {index_name}")
    
    index_body = {
        "settings": {
            "index": {
                "knn": True,
                "knn.algo_param.ef_search": 100,
                "number_of_shards": 1,
                "number_of_replicas": 0
            }
        },
        "mappings": {
            "properties": {
                "text": {
                    "type": "text"
                },
                "embedding": {
                    "type": "knn_vector",
                    "dimension": 1536,
                    "method": {
                        "name": "hnsw",
                        "space_type": "l2",
                        "engine": "nmslib",
                        "parameters": {
                            "ef_construction": 128,
                            "m": 24
                        }
                    }
                },
                "metadata": {
                    "type": "object",
                    "properties": {
                        "bucket": {"type": "keyword"},
                        "key": {"type": "keyword"},
                        "student_id": {"type": "keyword"}
                    }
                },
                "timestamp": {
                    "type": "date"
                }
            }
        }
    }
    
    try:
        opensearch_client.indices.create(index=index_name, body=index_body)
        print(f"Index {index_name} created successfully")
    except Exception as e:
        if 'resource_already_exists_exception' in str(e).lower():
            print(f"Index {index_name} already exists (race condition)")
        else:
            raise
