#!/bin/bash
# Script de actualización para Notesnook Self-Hosted

set -e

echo "=== Actualizando Notesnook Self-Hosted ==="

# Actualizar imágenes oficiales de backend
echo ""
echo "[1/3] Descargando últimas imágenes oficiales..."
docker compose pull notesnook-db notesnook-s3 identity-server notesnook-server sse-server monograph-server

# Reconstruir web app desde source (sin caché)
echo ""
echo "[2/3] Reconstruyendo web app desde source (esto tardará varios minutos)..."
docker compose build --no-cache notesnook-web

# Reiniciar servicios
echo ""
echo "[3/3] Reiniciando servicios..."
docker compose up -d

echo ""
echo "=== Actualización completada ==="
echo ""
echo "Verifica el estado con: docker compose ps"
echo "Ver logs con: docker compose logs -f"
