#!/bin/bash
set -e

ARCHIVO="evidencia_ejecucion.txt"

echo "Capturando logs en $ARCHIVO ..."
docker compose logs --no-color > "$ARCHIVO"
echo "Evidencia generada: $ARCHIVO"
