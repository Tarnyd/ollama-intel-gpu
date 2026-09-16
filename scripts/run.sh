#!/bin/bash
# Run the image locally (Linux with Intel GPU).
# Usage: ./scripts/run.sh [tag]
set -euo pipefail
TAG="${1:-tarnyd/ollama-intel-gpu:latest}"
docker run -d --name ollama-intel-gpu \
  --device=/dev/dri \
  -p 11434:11434 \
  -v ollama-data:/root/.ollama \
  --restart unless-stopped \
  "$TAG"
echo "Started ollama-intel-gpu. Logs: docker logs -f ollama-intel-gpu"
