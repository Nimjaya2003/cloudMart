# ---- Stage 1: build (install dependencies) ----
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Stage 2: runtime (small, no build leftovers) ----
FROM python:3.12-slim
ARG GIT_SHA=dev
RUN useradd --create-home --uid 10001 appuser
WORKDIR /app
COPY --from=builder /install /usr/local
COPY app.py .
ENV PYTHONUNBUFFERED=1 \
    APP_VERSION=${GIT_SHA}
USER appuser
EXPOSE 8080
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]