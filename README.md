# Ollama for Intel Arc GPUs (IPEX-LLM)

Docker image that runs [Ollama](https://ollama.com) on Intel Arc GPUs using
[Intel IPEX-LLM](https://github.com/ipex-llm/ipex-llm). Drop-in replacement
for the standard NVIDIA-based Ollama container — same API on port `11434`.

**Supported GPUs:** Intel Arc B580, A770, A750, A380 and other Arc series
(plus Intel iGPUs that expose `/dev/dri` — YMMV).

Docker Hub: **`tarnyd/ollama-intel-gpu`**

```bash
docker pull tarnyd/ollama-intel-gpu:latest
```

## How it works

Upstream `ollama/ollama` has no Intel GPU support. This image therefore:

1. Starts from `ubuntu:24.04`.
2. Installs the Intel GPU **userspace** drivers (IGC compiler, compute-runtime
   Level-Zero/OpenCL, Level-Zero loader, `ocl-icd-libopencl1`). The host kernel
   driver (`i915`/`xe`) and `/dev/dri` come from the host — the container only
   needs `--device=/dev/dri`.
3. Downloads the **IPEX-LLM Ollama portable build**
   (`ollama-ipex-llm-*-ubuntu.tgz` from
   [`ipex-llm/ipex-llm` releases, tag `v2.3.0-nightly`](https://github.com/ipex-llm/ipex-llm/releases/tag/v2.3.0-nightly))
   which bundles Ollama with a SYCL/Level-Zero backend, and extracts it to `/`.
4. Runs `/ollama serve` (via `entrypoint.sh`) listening on `0.0.0.0:11434`.

This follows the same approach as
[`mattcurf`/`justjoseorg/ollama-intel-gpu`](https://github.com/justjoseorg/ollama-intel-gpu)
and [`SpaceinvaderOne/ollama-intel-gpu`](https://github.com/SpaceinvaderOne/ollama-intel-gpu),
with two fixes relative to the older projects:

- Uses the newest portable build (`ollama-ipex-llm-2.3.0b20250725-ubuntu.tgz`,
  Ollama v0.9.x core) instead of the stale `v2.2.0` builds.
- Bypasses Intel's `start-ollama.sh`, which hardcodes
  `OLLAMA_HOST=127.0.0.1` and breaks Docker networking — the image runs
  `/ollama serve` directly so `OLLAMA_HOST` is honoured.

> **Ollama core version note:** the Ollama version is decided by whatever Intel
> ships in the portable tgz (currently v0.9.x, July 2025 — the latest Intel has
> published). It runs all current models from `ollama.com/library`. If you need
> a newer Ollama core than Intel's bundle, see [Alternatives](#alternatives).

## Install on Unraid

### Option A — manual template (works today)

1. **Docker → Add Container → Template**, paste the raw URL of
   `ollama-intel-gpu.xml` from your git repo, e.g.
   `https://raw.githubusercontent.com/<user>/ollama-intel-gpu/main/ollama-intel-gpu.xml`.
2. Settings:
   - **Model Storage** — `/mnt/user/appdata/ollama-intel-gpu` (models are 4–20 GB each).
   - **Ollama API Port** — `11434`.
   - **GPU Device Selector** — leave `level_zero:0` unless you have several Intel GPUs.
3. **Apply.** The template passes `--device=/dev/dri` automatically.

### Option B — Community Applications

CA does not index Docker Hub directly; templates ship via a template
repository. To list this container on CA, host `ollama-intel-gpu.xml` in a
templates repo (pattern:
[`SpaceinvaderOne/Docker-Templates-Unraid`](https://github.com/SpaceinvaderOne/Docker-Templates-Unraid))
and submit that repo to CA. Update `Repository`, `TemplateURL`, `Icon` and
support links in the XML to your own repo first.

### Verify it's working

Docker tab → container icon → **Logs**. Expect:

```text
[entrypoint] /dev/dri present:
oneAPI device name: Intel(R) Graphics [...]
inference compute  id=0 library=oneapi name="Intel(R) Graphics [...]" total="... GiB"
```

### Pull a model

Docker tab → container icon → **Console**:

```bash
ollama run llama3.1:8b "Hello!"
```

Small VRAM (B580 12 GB) starter picks: `qwen3:8b`, `llama3.1:8b`,
`mistral:7b`. Larger cards (A770 16 GB) can try `llama3.1:8b-instruct-q8_0`,
`deepseek-r1:8b/14b`.

### Use with Open WebUI

Point Open WebUI at `http://<UNRAID_IP>:11434`. The template sets
`OLLAMA_ORIGINS=*` by default so cross-origin frontends connect.

## Install on Linux

Requirements: Intel Arc GPU, `/dev/dri` present, `i915`/`xe` kernel driver loaded.

```bash
docker run -d \
  --name ollama-intel-gpu \
  --device=/dev/dri \
  -p 11434:11434 \
  -v ollama-data:/root/.ollama \
  tarnyd/ollama-intel-gpu:latest

docker exec -it ollama-intel-gpu ollama run llama3.1:8b "Hello!"
```

With compose (builds locally, keeps versions from `docker-compose.yml`):

```bash
cp .env.example .env   # optional
docker compose up -d --build
./scripts/test-api.sh
```

With Open WebUI:

```bash
docker compose -f docker-compose.yml -f docker-compose.open-webui.yml up -d --build
# WebUI: http://localhost:3000 , Ollama: http://localhost:11434
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_HOST` | `0.0.0.0:11434` | API listen address |
| `OLLAMA_INTEL_GPU` | `1` (baked in) | **Required.** Gates oneAPI discovery in ollama (`discover/gpu.go`); without it the server silently uses CPU despite a healthy driver stack |
| `ONEAPI_DEVICE_SELECTOR` | unset (correct) | Only for multi-GPU hosts: set manually, e.g. `level_zero:1`. Do NOT set it on single-GPU systems |
| `OLLAMA_NUM_GPU` | `999` | Offload all layers to GPU |
| `OLLAMA_NUM_PARALLEL` | `1` | Parallel requests (keep 1 on ≤12 GB) |
| `OLLAMA_NUM_CTX` | `4096` | Context window (tokens; more = more VRAM) |
| `OLLAMA_KEEP_ALIVE` | `10m` | Keep model in VRAM (`-1` = forever) |
| `OLLAMA_ORIGINS` | `*` (compose) | CORS origins for Open WebUI |
| `ZES_ENABLE_SYSMAN` | `1` | Expose VRAM stats via Level-Zero |
| `SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS` | `1` | Intel-recommended perf flag |
| `SYCL_CACHE_PERSISTENT` | `1` | Persistent SYCL kernel cache |

## Testing the API

```bash
curl http://localhost:11434/            # -> "Ollama is running"
curl http://localhost:11434/api/tags    # list models
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.1:8b", "prompt": "Hello!", "stream": false
}'
```

Or: `./scripts/test-api.sh`.

## What's inside

- **Base:** Ubuntu 24.04
- **IPEX-LLM portable:** `ollama-ipex-llm-2.3.0b20250725-ubuntu.tgz` (Ollama v0.9.x core)
- **Drivers:** IGC v2.8.3, compute-runtime 25.09.32961.7, Level-Zero loader v1.21.9
- **Healthcheck:** `curl http://127.0.0.1:11434/` every 30 s

## Model compatibility

The bundled llama.cpp/ggml is from July 2025: it runs everything with an
architecture known at that time (`qwen3`, `llama3.x`, `mistral`, `gemma3`,
`deepseek-r1`, `phi4`, …). Brand-new architectures fail at load with
`unable to load model` — e.g. IFM's `K2-Horizon` family (Sep 2026), whose
llama.cpp support PR was still in progress at release. Some very new
registry entries refuse even earlier, at pull time with
`412: requires a newer version of Ollama` (e.g. `gemma4`) — same root
cause: the bundled Ollama core predates the model family. There is no newer
IPEX-LLM portable to upgrade to (verified 2026-09-29); options are waiting
for Intel, or building current llama.cpp/Ollama from source with a SYCL
backend (see [Alternatives](#alternatives)). Rule of thumb: if the model
family was released after ~July 2025, check llama.cpp support first.

## Updating versions

1. Check [`ipex-llm/ipex-llm` releases (`v2.3.0-nightly`)](https://github.com/ipex-llm/ipex-llm/releases/tag/v2.3.0-nightly)
   for a newer `ollama-ipex-llm-*-ubuntu.tgz`.
2. Bump `IPEXLLM_PORTABLE_TGZ` in `Dockerfile` (+ `docker-compose.yml` args).
3. Keep the driver set together — newer compute-runtime releases renamed
   `intel-level-zero-gpu` → `libze-intel-gpu1`, so a driver bump also means
   editing the `dpkg -i` package list. When in doubt, keep the pinned set:
   it is the one validated against this portable build.
4. Rebuild: `./scripts/build.sh`, test with `./scripts/test-api.sh`, then push.

## Publishing to Docker Hub (`tarnyd`)

Manual flow (see also `.github/workflows/docker-build-push.yml` for CI):

```bash
docker login                                  # <-- YOU run this (once)
./scripts/build.sh tarnyd/ollama-intel-gpu:latest
./scripts/test-api.sh
./scripts/push.sh tarnyd/ollama-intel-gpu:latest
# optional tags:
docker tag tarnyd/ollama-intel-gpu:latest tarnyd/ollama-intel-gpu:b20250725
docker push tarnyd/ollama-intel-gpu:b20250725
```

CI flow: set repo secrets `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN`
(Docker Hub access token), push to `main` — the workflow builds
`linux/amd64` and pushes `:latest` (+ `:v*` tags and short-SHA).

## Troubleshooting

- **`/dev/dri` missing / falls back to CPU** — host has no Intel GPU visible,
  or you forgot `--device=/dev/dri`. Check `ls -la /dev/dri` on the host.
- **`no compatible GPUs were discovered`** — userspace/host driver mismatch.
  Keep the pinned driver set; don't mix a bleeding-edge host stack with this
  portable build without testing.
- **GPU visible in `/dev/dri` but log shows `library=cpu`** — Level-Zero found
  0 devices. Almost always Resizable BAR: the Arc needs its full VRAM mapped.
  Verify on the host (replace `0e:00.0` with your card's address from `lspci`):
  `lspci -s 0e:00.0 -vvv | grep -iA3 'Resizable BAR'` should show
  `current size` >= VRAM (e.g. 8GB on a 6GB A380), and `dmesg` must not contain
  `Using a reduced BAR size` / `Failed to resize BAR`. Fix checklist: Above 4G
  Decoding on, Re-Size BAR on/Auto, CSM off (pure UEFI boot), GPU in a
  CPU-attached slot — then a **full cold boot** (PSU off; warm reboots don't
  always rebuild the PCIe address map, and a BIOS update resets every setting).
  Verified on: Gigabyte X570 AORUS ULTRA + Arc A380, where only the cold boot
  after the BIOS update created the 64-bit MMIO window.
- **Log shows `library=cpu` but drivers are fine** (`clinfo`/`zeInit` see the
  card) — check two things: (1) `OLLAMA_INTEL_GPU=1` must be set (baked into
  this image; it gates oneAPI discovery — without it ollama never probes
  Level-Zero); (2) `ONEAPI_DEVICE_SELECTOR` is unneeded on single-GPU
  systems — leave it unset (proven harmless either way, but only multi-GPU
  hosts benefit). Verify with `docker logs <name> | grep "inference compute"`.
- **Multiple GPUs (iGPU + Arc)** — add `ONEAPI_DEVICE_SELECTOR` manually
  (extra Variable in Unraid, e.g. `level_zero:1`). It is deliberately unset
  by default: single-GPU systems must not set it.
- **OOM on 12 GB cards** — lower `OLLAMA_NUM_CTX` (2048), keep
  `OLLAMA_NUM_PARALLEL=1`, use smaller quants (`q4_K_M`).
- **Open WebUI can't connect** — ensure `OLLAMA_ORIGINS=*` and
  `OLLAMA_BASE_URL=http://<host>:11434` (not `127.0.0.1` from another host).

## Alternatives

- [`eleiton/ollama-intel-arc`](https://github.com/eleiton/ollama-intel-arc) —
  builds Ollama from source with a native SYCL backend (tracks upstream Ollama
  directly, no IPEX-LLM). More current Ollama core, but you compile it yourself.
- [`intel/ipex-llm` official images](https://github.com/intel/ipex-llm/tree/main/docker/llm/inference-cpp) —
  `intelanalytics/ipex-llm-inference-cpp-xpu`.

## Credits

Approach derived from `mattcurf/ollama-intel-gpu` →
`justjoseorg/ollama-intel-gpu` (ghcr.io/justjoseorg/ollama-intel-gpu) and
`SpaceinvaderOne/ollama-intel-gpu` (IPEX-LLM portable + Intel userspace
drivers on Ubuntu 24.04). This repo updates the portable build, fixes the
`OLLAMA_HOST` entrypoint bug, and adds healthcheck, compose files, Unraid
template, and CI. Intel IPEX-LLM and Ollama belong to their respective owners.

## License

MIT — see [LICENSE](LICENSE).
