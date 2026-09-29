# Changelog

## [Unreleased]
- README: troubleshooting entry for `library=cpu` fallback (Resizable BAR
  verification + cold-boot requirement), verified on X570 AORUS ULTRA + Arc A380.

## [1.0.0] — 2026-09-16
- Initial public release as `tarnyd/ollama-intel-gpu`.
- IPEX-LLM portable `ollama-ipex-llm-2.3.0b20250725-ubuntu.tgz` (Ollama v0.9.x core).
- Intel userspace drivers: IGC v2.8.3, compute-runtime 25.09.32961.7, Level-Zero loader v1.21.9.
- `entrypoint.sh` runs `/ollama serve` directly (fixes `OLLAMA_HOST=127.0.0.1` hardcode in Intel's `start-ollama.sh`).
- Healthcheck, OCI labels, `ONEAPI_DEVICE_SELECTOR`/`OLLAMA_*` defaults.
- `docker-compose.yml`, `docker-compose.open-webui.yml`, Unraid template `ollama-intel-gpu.xml`, CI workflow, scripts, README/AGENTS docs.
