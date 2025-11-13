#!/usr/bin/env bash
set -e

echo "🚀 Subindo LocalStack..."
docker compose up -d

echo "⏳ Aguardando LocalStack iniciar..."
