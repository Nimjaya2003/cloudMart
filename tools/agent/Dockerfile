
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    OMP_NUM_THREADS=2 \
    MKL_NUM_THREADS=2

WORKDIR /opt/cloudmart

# Native runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Install CPU-compatible PyTorch
RUN pip install torch==2.9.1 \
    --index-url https://download.pytorch.org/whl/cpu

# Install the agent dependencies
COPY tools/agent/requirements.txt /tmp/requirements.txt

RUN pip install -r /tmp/requirements.txt

RUN pip check

# Download the same MiniLM revision
ARG MINILM_REVISION

RUN test -n "$MINILM_REVISION"

RUN python -c "import os; from sentence_transformers import SentenceTransformer; model = SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2',revision=os.environ['MINILM_REVISION'],device='cpu'); model.save_pretrained('/opt/minilm')"

# Copy our existing Phase 8 code
COPY tools/kb/kb_common.py tools/kb/kb_common.py
COPY tools/kb/ask.py tools/kb/ask.py

# Copy the new Phase 10 code
COPY tools/agent/llm_client.py tools/agent/llm_client.py
COPY tools/agent/gateway_client.py tools/agent/gateway_client.py
COPY tools/agent/agent_tools.py tools/agent/agent_tools.py
COPY tools/agent/agent.py tools/agent/agent.py
COPY tools/agent/server.py tools/agent/server.py

# Load MiniLM without downloading at runtime
ENV KB_MODEL_PATH=/opt/minilm \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1


# Create non-root application user
RUN useradd --create-home --uid 10001 appuser

# Allow the application user to read the model files
RUN chmod -R a+rX /opt/minilm

# Run the application as a non-root user
USER appuser

WORKDIR /opt/cloudmart/tools/agent

# Verify model inference as the actual application user
RUN python -c "from sentence_transformers import SentenceTransformer; m=SentenceTransformer('/opt/minilm', device='cpu', local_files_only=True); v=m.encode('CloudMart embedding test', normalize_embeddings=True); assert v.shape == (384,); print('MiniLM offline embedding test passed:', v.shape)"


EXPOSE 8080

CMD ["gunicorn", \
     "--bind", "0.0.0.0:8080", \
     "--workers", "1", \
     "--threads", "2", \
     "--timeout", "300", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "server:app"]
