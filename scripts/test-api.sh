#!/bin/bash
# Smoke-test a running instance: health endpoint, list models, tiny generate.
# Usage: ./scripts/test-api.sh [host]   (default: http://localhost:11434)
set -euo pipefail
BASE="${1:-http://localhost:11434}"
echo "== GET $BASE/ =="
curl -fsS "$BASE/" && echo
echo "== GET $BASE/api/tags =="
curl -fsS "$BASE/api/tags" && echo
echo "OK: API reachable. Pull a model, e.g.:"
echo "  docker exec -it ollama-intel-gpu ollama run llama3.1:8b \"Hello!\""
