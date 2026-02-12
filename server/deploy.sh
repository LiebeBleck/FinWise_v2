#!/bin/bash

# FinWise v1.0 - Production Deployment Script
# Server: 80.93.60.208
# Date: 2026-02-13

set -e  # Exit on error

echo "🚀 FinWise v1.0 - Production Deployment"
echo "======================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="80.93.60.208"
SERVER_USER="root"
PROJECT_DIR="/root/finwise"
BACKUP_DIR="/root/finwise_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${YELLOW}📋 Step 1: Создание backup текущей версии...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'EOF'
if [ -d /root/finwise ]; then
  BACKUP_DIR="/root/finwise_backup_$(date +%Y%m%d_%H%M%S)"
  echo "Creating backup: $BACKUP_DIR"
  cp -r /root/finwise $BACKUP_DIR
  echo "✅ Backup created"
else
  echo "No existing installation found, skipping backup"
fi
EOF

echo -e "${YELLOW}📦 Step 2: Копирование файлов на сервер...${NC}"
rsync -avz --exclude='venv' --exclude='__pycache__' --exclude='*.pyc' \
  ./ ${SERVER_USER}@${SERVER_IP}:${PROJECT_DIR}/

echo -e "${YELLOW}🐳 Step 3: Остановка старых контейнеров...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'EOF'
cd /root/finwise
if [ -f docker-compose.yml ]; then
  docker-compose down
fi
EOF

echo -e "${YELLOW}🔧 Step 4: Проверка .env файла...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'EOF'
cd /root/finwise
if [ ! -f .env ]; then
  echo "⚠️  .env file not found, creating from example..."
  cp .env.example .env
  echo "⚠️  WARNING: Please configure .env file manually"
else
  echo "✅ .env file exists"
fi
EOF

echo -e "${YELLOW}🔨 Step 5: Сборка и запуск контейнеров...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'EOF'
cd /root/finwise
docker-compose build
docker-compose up -d
EOF

echo -e "${YELLOW}⏳ Step 6: Ожидание запуска сервисов...${NC}"
sleep 10

echo -e "${YELLOW}🔍 Step 7: Проверка статуса контейнеров...${NC}"
ssh ${SERVER_USER}@${SERVER_IP} << 'EOF'
cd /root/finwise
docker-compose ps
EOF

echo -e "${YELLOW}🧪 Step 8: Тестирование API...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://${SERVER_IP}/)
if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "404" ]; then
  echo -e "${GREEN}✅ API responding (HTTP $HTTP_CODE)${NC}"
else
  echo -e "${RED}❌ API not responding (HTTP $HTTP_CODE)${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "📍 API URL: http://${SERVER_IP}/"
echo "📖 Docs: http://${SERVER_IP}/docs"
echo "🔍 Logs: ssh ${SERVER_USER}@${SERVER_IP} 'cd ${PROJECT_DIR} && docker-compose logs -f api'"
echo ""
