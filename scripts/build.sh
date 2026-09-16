#!/bin/bash
# Build the image locally.
# Usage: ./scripts/build.sh [tag]   (default tag: tarnyd/ollama-intel-gpu:latest)
set -euo pipefail
TAG="${1:-tarnyd/ollama-intel-gpu:latest}"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker build -t "$TAG" "$DIR"
echo "Built $TAG"
docker images "$TAG"
