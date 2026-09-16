# =============================================================================
# Ollama for Intel Arc GPUs (IPEX-LLM)
# =============================================================================
# Packages the IPEX-LLM optimised Ollama portable build with Intel GPU
# userspace drivers into a minimal Ubuntu 24.04 container.
#
# Drop-in replacement for the standard Ollama container — same API on
# port 11434. Requires an Intel Arc GPU on the host (/dev/dri).
#
# Tested with: Intel Arc B580 12 GB, A770, A750, A380
#
# Build:
#   docker build -t tarnyd/ollama-intel-gpu:latest .
#   # or: ./scripts/build.sh
#
# Run:
#   docker run -d --name ollama-intel-gpu \
#     --device=/dev/dri \
#     -p 11434:11434 \
#     -v ollama-data:/root/.ollama \
#     tarnyd/ollama-intel-gpu:latest
#
# All versions are pinned via build args so a rebuild is reproducible.
# Override at build time, e.g.:
#   --build-arg IPEXLLM_PORTABLE_TGZ=ollama-ipex-llm-2.3.0b20250725-ubuntu.tgz
# =============================================================================

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# ---------------------------------------------------------------------------
# Build arguments — override at build time to pin different versions
# ---------------------------------------------------------------------------

# Intel Graphics Compiler (IGC)
ARG IGC_VERSION=v2.8.3
ARG IGC_CORE_DEB=intel-igc-core-2_2.8.3+18762_amd64.deb
ARG IGC_OPENCL_DEB=intel-igc-opencl-2_2.8.3+18762_amd64.deb

# Intel Compute Runtime (Level-Zero GPU driver, OpenCL ICD, gmmlib)
# NOTE: 25.09.32961.7 is the last release using the intel-level-zero-gpu
# package name. Newer compute-runtime releases renamed it to
# libze-intel-gpu1 — stick to this set unless you also update the
# package list below. It is the set validated against the IPEX-LLM
# portable build used here.
ARG COMPUTE_RT_VERSION=25.09.32961.7
ARG LEVEL_ZERO_GPU_DEB=intel-level-zero-gpu_1.6.32961.7_amd64.deb
ARG OPENCL_ICD_DEB=intel-opencl-icd_25.09.32961.7_amd64.deb
ARG GMMLIB_DEB=libigdgmm12_22.6.0_amd64.deb

# Level-Zero Loader
ARG LEVEL_ZERO_LOADER_VERSION=v1.21.9
ARG LEVEL_ZERO_LOADER_DEB=level-zero_1.21.9+u24.04_amd64.deb

# IPEX-LLM Ollama portable package (bundles Ollama + SYCL/Level-Zero backend)
# The bundled Ollama core version is decided by Intel; b20250725 ships
# Ollama v0.9.x. Check https://github.com/ipex-llm/ipex-llm/releases
# tag v2.3.0-nightly for newer ollama-ipex-llm-*-ubuntu.tgz files.
ARG IPEXLLM_RELEASE_REPO=ipex-llm/ipex-llm
ARG IPEXLLM_RELEASE_VERSION=v2.3.0-nightly
ARG IPEXLLM_PORTABLE_TGZ=ollama-ipex-llm-2.3.0b20250725-ubuntu.tgz

# Image version label (set by CI, defaults to dev)
ARG IMAGE_VERSION=dev

LABEL org.opencontainers.image.title="Ollama for Intel Arc GPUs (IPEX-LLM)" \
      org.opencontainers.image.description="Ollama with Intel Arc GPU acceleration via IPEX-LLM. Drop-in replacement for the standard Ollama container." \
      org.opencontainers.image.version="${IMAGE_VERSION}" \
      org.opencontainers.image.source="https://github.com/ipex-llm/ipex-llm" \
      org.opencontainers.image.licenses="MIT"

# ---------------------------------------------------------------------------
# Step 1: Install base packages
# ---------------------------------------------------------------------------
RUN apt-get update && \
    apt-get install --no-install-recommends -q -y \
        ca-certificates \
        curl \
        wget \
        ocl-icd-libopencl1 && \
    rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Step 2: Install Intel GPU userspace drivers
# ---------------------------------------------------------------------------
RUN mkdir -p /tmp/gpu && cd /tmp/gpu && \
    wget -q https://github.com/oneapi-src/level-zero/releases/download/${LEVEL_ZERO_LOADER_VERSION}/${LEVEL_ZERO_LOADER_DEB} && \
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/${IGC_VERSION}/${IGC_CORE_DEB} && \
    wget -q https://github.com/intel/intel-graphics-compiler/releases/download/${IGC_VERSION}/${IGC_OPENCL_DEB} && \
    wget -q https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RT_VERSION}/${LEVEL_ZERO_GPU_DEB} && \
    wget -q https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RT_VERSION}/${OPENCL_ICD_DEB} && \
    wget -q https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RT_VERSION}/${GMMLIB_DEB} && \
    dpkg -i ./*.deb && \
    rm -rf /tmp/gpu

# ---------------------------------------------------------------------------
# Step 3: Download and extract IPEX-LLM Ollama portable package
# ---------------------------------------------------------------------------
RUN wget -q -P /tmp "https://github.com/${IPEXLLM_RELEASE_REPO}/releases/download/${IPEXLLM_RELEASE_VERSION}/${IPEXLLM_PORTABLE_TGZ}" && \
    tar xf "/tmp/${IPEXLLM_PORTABLE_TGZ}" --strip-components=1 -C / && \
    rm "/tmp/${IPEXLLM_PORTABLE_TGZ}" && \
    chmod +x /ollama && \
    /ollama --version || true

# ---------------------------------------------------------------------------
# Step 4: Configure runtime environment
# ---------------------------------------------------------------------------
# IPEX-LLM / Intel GPU settings (same as Intel's start-ollama.sh, minus the
# hardcoded OLLAMA_HOST=127.0.0.1 which would break Docker networking).
ENV OLLAMA_NUM_GPU=999 \
    ZES_ENABLE_SYSMAN=1 \
    SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 \
    SYCL_CACHE_PERSISTENT=1 \
    no_proxy=localhost,127.0.0.1

# Ollama settings (all overridable with -e / Unraid template)
ENV OLLAMA_HOST=0.0.0.0:11434 \
    ONEAPI_DEVICE_SELECTOR=level_zero:0 \
    OLLAMA_NUM_PARALLEL=1 \
    OLLAMA_NUM_CTX=4096 \
    OLLAMA_KEEP_ALIVE=10m

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 11434
VOLUME ["/root/.ollama"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -fsS http://127.0.0.1:11434/ || exit 1

# Run ollama serve via the wrapper (which only logs GPU status, then execs).
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["serve"]
