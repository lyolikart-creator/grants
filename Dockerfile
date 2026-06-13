FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    gcc \
    libgomp1 \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# ВАЖНО: используем переменную $PORT от Railway, а не 8000!
CMD uvicorn api.main:app --host 0.0.0.0 --port $PORT
