"""
Lambda Function - Test de Conectividad
Prueba conexiones a OpenSearch y Bedrock
"""

import json
import boto3
import os
from opensearchpy import OpenSearch, RequestsHttpConnection
from requests_aws4auth import AWS4Auth
from datetime import datetime

# Configuración de clientes AWS
s3_client = boto3.client('s3')
# AWS_REGION es proporcionada automáticamente por Lambda
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


def handler(event, context):
    """
    Test de conectividad
    """
    print(f"=== TEST DE CONECTIVIDAD ===")
    print(f"Event: {json.dumps(event)}")
    print(f"Region: {region}")
    print(f"Student ID: {os.environ.get('STUDENT_ID', 'N/A')}")
    
    results = {
        'timestamp': datetime.utcnow().isoformat(),
        'student_id': os.environ.get('STUDENT_ID', 'N/A'),
        'region': region,
        'tests': {}
    }
    
    # Test 1: OpenSearch Connection
    print("\n--- Test 1: OpenSearch Connection ---")
    try:
        info = opensearch_client.info()
        results['tests']['opensearch'] = {
            'status': 'SUCCESS',
            'cluster_name': info['cluster_name'],
            'version': info['version']['number'],
            'message': 'Conexión exitosa a OpenSearch'
        }
        print(f"✓ OpenSearch OK: {info['cluster_name']} v{info['version']['number']}")
    except Exception as e:
        results['tests']['opensearch'] = {
            'status': 'FAILED',
            'error': str(e),
            'message': 'No se pudo conectar a OpenSearch'
        }
        print(f"✗ OpenSearch ERROR: {str(e)}")
    
    # Test 2: OpenSearch Cluster Health
    print("\n--- Test 2: OpenSearch Cluster Health ---")
    try:
        health = opensearch_client.cluster.health()
        results['tests']['opensearch_health'] = {
            'status': 'SUCCESS',
            'cluster_status': health['status'],
            'number_of_nodes': health['number_of_nodes'],
            'active_shards': health['active_shards'],
            'message': f"Cluster status: {health['status']}"
        }
        print(f"✓ Cluster Health: {health['status']} ({health['number_of_nodes']} nodes)")
    except Exception as e:
        results['tests']['opensearch_health'] = {
            'status': 'FAILED',
            'error': str(e)
        }
        print(f"✗ Cluster Health ERROR: {str(e)}")
    
    # Test 3: Listar índices de OpenSearch
    print("\n--- Test 3: OpenSearch Indices ---")
    try:
        indices = opensearch_client.cat.indices(format='json')
        student_index = os.environ.get('OPENSEARCH_INDEX', 'N/A')
        
        # Buscar si existe el índice del estudiante
        student_index_exists = any(idx['index'] == student_index for idx in indices)
        
        results['tests']['opensearch_indices'] = {
            'status': 'SUCCESS',
            'total_indices': len(indices),
            'student_index': student_index,
            'student_index_exists': student_index_exists,
            'message': f"Tu índice '{student_index}' {'existe' if student_index_exists else 'aún no existe (se creará al indexar primer documento)'}"
        }
        print(f"✓ Índices encontrados: {len(indices)}")
        print(f"  Tu índice '{student_index}': {'existe' if student_index_exists else 'no existe aún'}")
    except Exception as e:
        results['tests']['opensearch_indices'] = {
            'status': 'FAILED',
            'error': str(e)
        }
        print(f"✗ Indices ERROR: {str(e)}")
    
    # Test 4: Bedrock Connection
    print("\n--- Test 4: Bedrock Connection ---")
    try:
        model_id = os.environ.get('BEDROCK_MODEL_ID', 'amazon.titan-embed-text-v1')
        
        # Generar embedding de prueba
        test_text = "Test de conectividad"
        body = json.dumps({"inputText": test_text})
        
        response = bedrock_client.invoke_model(
            modelId=model_id,
            body=body
        )
        
        response_body = json.loads(response['body'].read())
        embedding = response_body['embedding']
        
        results['tests']['bedrock'] = {
            'status': 'SUCCESS',
            'model_id': model_id,
            'embedding_dimensions': len(embedding),
            'test_text': test_text,
            'message': 'Conexión exitosa a Bedrock'
        }
        print(f"✓ Bedrock OK: Generó embedding de {len(embedding)} dimensiones")
    except Exception as e:
        results['tests']['bedrock'] = {
            'status': 'FAILED',
            'model_id': os.environ.get('BEDROCK_MODEL_ID', 'N/A'),
            'error': str(e),
            'message': 'No se pudo conectar a Bedrock'
        }
        print(f"✗ Bedrock ERROR: {str(e)}")
    
    # Test 5: S3 Connection
    print("\n--- Test 5: S3 Connection ---")
    try:
        bucket_name = os.environ.get('S3_BUCKET', 'N/A')
        
        # Verificar que el bucket existe
        s3_client.head_bucket(Bucket=bucket_name)
        
        # Listar objetos (primeros 10)
        response = s3_client.list_objects_v2(
            Bucket=bucket_name,
            Prefix='documents/',
            MaxKeys=10
        )
        
        object_count = response.get('KeyCount', 0)
        
        results['tests']['s3'] = {
            'status': 'SUCCESS',
            'bucket_name': bucket_name,
            'documents_count': object_count,
            'message': f"Bucket accesible. Documentos: {object_count}"
        }
        print(f"✓ S3 OK: Bucket '{bucket_name}' accesible con {object_count} documentos")
    except Exception as e:
        results['tests']['s3'] = {
            'status': 'FAILED',
            'bucket_name': os.environ.get('S3_BUCKET', 'N/A'),
            'error': str(e),
            'message': 'No se pudo conectar a S3'
        }
        print(f"✗ S3 ERROR: {str(e)}")
    
    # Resumen final
    print("\n=== RESUMEN ===")
    total_tests = len(results['tests'])
    successful_tests = sum(1 for test in results['tests'].values() if test['status'] == 'SUCCESS')
    
    results['summary'] = {
        'total_tests': total_tests,
        'successful': successful_tests,
        'failed': total_tests - successful_tests,
        'success_rate': f"{(successful_tests/total_tests)*100:.1f}%"
    }
    
    print(f"Tests exitosos: {successful_tests}/{total_tests} ({results['summary']['success_rate']})")
    
    # Determinar status code
    if successful_tests == total_tests:
        status_code = 200
        print("✓ TODOS LOS TESTS PASARON")
    elif successful_tests > 0:
        status_code = 207  # Multi-Status
        print("⚠ ALGUNOS TESTS FALLARON")
    else:
        status_code = 500
        print("✗ TODOS LOS TESTS FALLARON")
    
    return {
        'statusCode': status_code,
        'body': json.dumps(results, indent=2)
    }
