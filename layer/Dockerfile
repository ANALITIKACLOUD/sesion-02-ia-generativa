# Usar la imagen oficial de AWS Lambda para Python 3.9
FROM public.ecr.aws/lambda/python:3.9

# Instalar dependencias en /opt/python
RUN mkdir -p /opt/python

# Copiar requirements.txt
COPY requirements.txt /tmp/

# Instalar dependencias
RUN pip install -r /tmp/requirements.txt -t /opt/python --no-cache-dir

# Limpiar archivos innecesarios
RUN find /opt/python -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/python -type d -name "test" -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/python -type f -name "*.pyc" -delete 2>/dev/null || true && \
    find /opt/python -type f -name "*.pyo" -delete 2>/dev/null || true && \
    find /opt/python -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/python -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/python -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true

# El directorio /opt será extraído
CMD ["/bin/bash"]
