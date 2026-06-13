FROM python:3.11-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    gcc \
    libgomp1 \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копирование requirements и установка Python-пакетов
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование всего проекта
COPY . .

# Запуск приложения
ENV PORT=8000
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
