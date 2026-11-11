#!/bin/bash
set -e

echo "Construyendo y levantando el sistema de atracadero..."
docker compose up --build
