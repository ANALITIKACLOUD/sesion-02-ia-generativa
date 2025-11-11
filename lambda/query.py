"""
Lambda Query - Búsqueda semántica en OpenSearch
Recibe queries y busca documentos similares usando embeddings
"""

import json
import os
from shared import opensearch_client, generate_embedding


def handler(event, context):
    """
    Handler para consultas RAG
    """
    print(f"Query received event: {json.dumps(event)}")
    
    try:
        # Parsear body del request
        if 'body' in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event
        
        # Validar que venga query
        if 'query' not in body:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Missing required field: query',
                    'usage': {
                        'body': {
                            'query': 'your search text',
                            'k': 5,  # opcional: número de resultados
                            'include_metadata': True  # opcional
                        }
                    }
                })
            }
        
        query_text = body['query']
        k = body.get('k', 5)  # Top K resultados por defecto
        include_metadata = body.get('include_metadata', True)
        
        print(f"Searching for: '{query_text}' (k={k})")
        
        # Realizar búsqueda
        results = search_documents(
            query_text=query_text,
            k=k,
            include_metadata=include_metadata
        )
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'query': query_text,
                'results_count': len(results),
                'results': results
            }, indent=2)
        }
    
    except Exception as e:
        print(f"Error processing query: {str(e)}")
        import traceback
        traceback.print_exc()
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e),
                'type': type(e).__name__
            })
        }


def search_documents(query_text, k=5, include_metadata=True):
    """
    Buscar documentos similares usando KNN search
    
    Args:
        query_text: Texto de la búsqueda
        k: Número de resultados a retornar
        include_metadata: Si incluir metadata en resultados
    
    Returns:
        Lista de documentos encontrados con scores
    """
    index_name = os.environ['OPENSEARCH_INDEX']
    
    # Generar embedding del query
    print(f"Generating query embedding...")
    query_embedding = generate_embedding(query_text)
    
    # Construir query KNN
    search_body = {
        "size": k,
        "query": {
            "knn": {
                "embedding": {
                    "vector": query_embedding,
                    "k": k
                }
            }
        }
    }
    
    # Ejecutar búsqueda
    print(f"Searching in index: {index_name}")
    response = opensearch_client.search(
        index=index_name,
        body=search_body
    )
    
    # Procesar resultados
    results = []
    hits = response['hits']['hits']
    
    print(f"Found {len(hits)} results")
    
    for hit in hits:
        source = hit['_source']
        
        result = {
            'document_id': hit['_id'],
            'score': hit['_score'],
            'text': source['text']
        }
        
        # Agregar metadata si se solicita
        if include_metadata and 'metadata' in source:
            result['metadata'] = source['metadata']
        
        # Agregar timestamp si existe
        if 'timestamp' in source:
            result['indexed_at'] = source['timestamp']
        
        results.append(result)
    
    return results


def search_with_filters(query_text, filters=None, k=5):
    """
    Búsqueda con filtros adicionales
    
    Args:
        query_text: Texto de búsqueda
        filters: Dict con filtros (ej: {"metadata.student_id": "12345"})
        k: Número de resultados
    
    Returns:
        Lista de documentos
    """
    index_name = os.environ['OPENSEARCH_INDEX']
    
    # Generar embedding
    query_embedding = generate_embedding(query_text)
    
    # Query base
    query = {
        "knn": {
            "embedding": {
                "vector": query_embedding,
                "k": k
            }
        }
    }
    
    # Agregar filtros si existen
    if filters:
        bool_query = {
            "bool": {
                "must": [query],
                "filter": []
            }
        }
        
        for field, value in filters.items():
            bool_query["bool"]["filter"].append({
                "term": {field: value}
            })
        
        query = bool_query
    
    search_body = {
        "size": k,
        "query": query
    }
    
    response = opensearch_client.search(
        index=index_name,
        body=search_body
    )
    
    # Procesar resultados
    results = []
    for hit in response['hits']['hits']:
        source = hit['_source']
        results.append({
            'document_id': hit['_id'],
            'score': hit['_score'],
            'text': source['text'],
            'metadata': source.get('metadata', {}),
            'indexed_at': source.get('timestamp')
        })
    
    return results
