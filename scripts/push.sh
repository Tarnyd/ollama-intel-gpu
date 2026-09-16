#!/bin/bash
# Push to Docker Hub. You must be logged in first: `docker login`
# Usage: ./scripts/push.sh [tag]   (default tag: tarnyd/ollama-intel-gpu:latest)
set -euo pipefail
TAG="${1:-tarnyd/ollama-intel-gpu:latest}"
docker push "$TAG"
echo "Pushed $TAG -> https://hub.docker.com/r/tarnyd/ollama-intel-gpu/"
