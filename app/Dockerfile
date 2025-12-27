FROM python:3.11-alpine AS builder
RUN apk add --no-cache build-base linux-headers
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip wheel --no-cache-dir --no-deps --wheel-dir /wheels -r requirements.txt

FROM python:3.11-alpine AS runtime
RUN apk add --no-cache postgresql-client
WORKDIR /app
COPY --from=builder /wheels /wheels
COPY . .
RUN pip install --no-cache-dir --force-reinstall /wheels/* && \
    rm -rf /wheels && \
    adduser -D appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

