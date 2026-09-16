#!/bin/bash
# Wrapper entrypoint: logs Intel GPU status, then execs `ollama serve`.
# All `ollama serve` flags/args can be passed as CMD. Env vars (OLLAMA_*,
# ONEAPI_DEVICE_SELECTOR, ...) are honoured by the ollama binary itself.
set -e

echo "[entrypoint] Starting ollama-intel-gpu"
echo "[entrypoint] OLLAMA_HOST=${OLLAMA_HOST:-0.0.0.0:11434} ONEAPI_DEVICE_SELECTOR=${ONEAPI_DEVICE_SELECTOR:-level_zero:0}"

if [ -e /dev/dri ]; then
  echo "[entrypoint] /dev/dri present:"
  ls -la /dev/dri || true
else
  echo "[entrypoint] WARNING: /dev/dri not found — container will fall back to CPU." >&2
  echo "[entrypoint] Re-run with --device=/dev/dri (Unraid template sets this automatically)." >&2
fi

# "$@" defaults to "serve" from Dockerfile CMD.
exec /ollama "$@"
