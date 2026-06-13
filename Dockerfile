FROM python:3.11-slim

# Установка системных зависимостей для asyncpg и scikit-learn
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Рабочая директория
WORKDIR /app

# Копирование и установка зависимостей
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Копирование всего проекта
COPY . .

# Открываем порт (информационно)
EXPOSE 8000

# Запуск приложения — Railway сам пробросит внешний порт на 8000
CMD uvicorn api.main:app --host 0.0.0.0 --port 8000
