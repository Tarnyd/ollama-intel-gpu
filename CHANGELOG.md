# Changelog

## [1.1.1] — 2026-09-29
- Fix: symlink `/ollama` to `/usr/local/bin/ollama` so the CLI is on `PATH`
  (`docker exec <name> ollama ...` and the Unraid console previously failed
  with "executable file not found in $PATH").
- Docs: corrected `ONEAPI_DEVICE_SELECTOR` wording (proven harmless on
  single-GPU, just unneeded — not the discovery bug).

## [1.1.0] — 2026-09-29
- Fix: bake `OLLAMA_INTEL_GPU=1` into the image. It gates oneAPI discovery
  (`discover/gpu.go: if envconfig.IntelGPU()`) — without it the server
  silently fell back to CPU on healthy systems. Verified on Arc A380:
  `library=oneapi`, 5.9 GiB VRAM.
- Fix: drop the unconditional `ONEAPI_DEVICE_SELECTOR=level_zero:0` default
  (Dockerfile, compose, Unraid template) to match Intel's commented-out
  default. It proved harmless on single-GPU (discovery works with or without
  it), but it is unneeded there — multi-GPU hosts set it manually.

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
