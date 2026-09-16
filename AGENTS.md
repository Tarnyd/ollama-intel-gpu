# AGENTS.md — working agreement for AI agents in this repo

This file tells an AI coding agent how to work in `ollama-intel-gpu`.
Follow it on every change. Keep the repo public-safe, generic and anonymous:
no personal names, emails, IPs, tokens or host paths.

## 1. Repo map

- `Dockerfile` — the image. Ubuntu 24.04 + Intel userspace drivers + IPEX-LLM
  Ollama portable tgz. Versions are build args; keep them pinned.
- `entrypoint.sh` — logs `/dev/dri` status, then `exec /ollama "$@"`.
  Keep it POSIX-ish bash, no secrets, no network calls.
- `docker-compose.yml` — local run (builds image, `/dev/dri`, volume, env).
- `docker-compose.open-webui.yml` — extends the above with Open WebUI.
- `ollama-intel-gpu.xml` — Unraid Community Applications template.
- `.github/workflows/docker-build-push.yml` — CI: buildx `linux/amd64`,
  push to `tarnyd/ollama-intel-gpu` on non-PR runs.
- `scripts/{build,run,test-api,push}.sh` — thin wrappers around docker CLI.
- `.env.example` — documented defaults. Never commit a real `.env`.
- `README.md` — user docs. `CHANGELOG.md` — release notes.

## 2. Golden rules

1. **Reproducibility first.** Never use `latest` URLs or unpinned packages for
   Intel drivers / IPEX-LLM. Every version must be a `Dockerfile` `ARG` with a
   default, mirrored in `docker-compose.yml` build args.
2. **Driver + portable compatibility.** The IPEX-LLM portable build is validated
   against a specific userspace driver set. Currently pinned:
   IGC `v2.8.3`, compute-runtime `25.09.32961.7` (`intel-level-zero-gpu`
   naming), Level-Zero loader `v1.21.9`, portable
   `ollama-ipex-llm-2.3.0b20250725-ubuntu.tgz`. Newer compute-runtime releases
   renamed packages to `libze-intel-gpu1`/`libze1` — a driver bump REQUIRES
   editing the download + `dpkg -i` list, not just the version string.
3. **Don't regress the entrypoint fix.** Intel's `start-ollama.sh` hardcodes
   `OLLAMA_HOST=127.0.0.1`. We run `/ollama serve` via `entrypoint.sh` so
   `OLLAMA_HOST` (default `0.0.0.0:11434`) is honoured. Never switch back to
   `start-ollama.sh` without fixing the bind address.
4. **Public-safe.** No usernames (except the `tarnyd` image namespace and
   documented `<user>` TODO placeholders), no IPs, no tokens, no local paths
   outside `/mnt/user/appdata/...` examples and `ollama-data` volumes.
5. **Small diffs.** Prefer editing existing files over adding new ones. Don't
   create docs beyond README/CHANGELOG unless asked.

## 3. How to update the IPEX-LLM portable build

1. Query the API (Windows PowerShell note: use `curl.exe`, not `curl`):
   `curl.exe -s https://api.github.com/repos/ipex-llm/ipex-llm/releases/tags/v2.3.0-nightly`
   and list assets containing `ollama` + `ubuntu.tgz`.
2. Update `IPEXLLM_PORTABLE_TGZ` default in `Dockerfile` AND the
   `docker-compose.yml` build arg. Mention the bundled Ollama core version in
   `README.md` ("What's inside") and `CHANGELOG.md` if known
   (Intel announces it, e.g. "from b20250630 supports ollama v0.9.3").
3. Rebuild + smoke test (see §5). Check `docker logs` for
   `library=oneapi` / `oneAPI device name`, then `./scripts/test-api.sh`.

## 4. How to update Intel drivers

1. Check the three repos' latest releases:
   `intel/intel-graphics-compiler`, `intel/compute-runtime`,
   `oneapi-src/level-zero`.
2. If `compute-runtime >= 25.13`, expect the `libze-intel-gpu1` naming —
   rewrite Step 2 of the Dockerfile accordingly and test carefully.
3. Prefer keeping the known-good set unless there is a specific reason
   (new GPU support, security fix). Record the reason in CHANGELOG.

## 5. Build / test commands

```bash
./scripts/build.sh tarnyd/ollama-intel-gpu:test
docker run -d --name t --device=/dev/dri -p 11434:11434 tarnyd/ollama-intel-gpu:test
docker logs -f t            # expect oneAPI / Level-Zero lines
./scripts/test-api.sh
docker rm -f t
```

- Linux-only GPU path: `--device=/dev/dri` needs a real Intel GPU; on hosts
  without one, only verify the image builds and the API serves on CPU.
- CI (`.github/workflows`) needs `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN`
  secrets; never invent or commit those values.
- Shell scripts: `set -euo pipefail`, LF line endings, `chmod +x`.

## 6. Unraid template rules

- `Repository` stays `tarnyd/ollama-intel-gpu`; `ExtraParams` must contain
  `--device=/dev/dri`; `Network` is `bridge`; keep the 7 Config entries
  (Model Storage path, Port 11434, 5 Variables) with their defaults.
- `TemplateURL` must point at the raw `ollama-intel-gpu.xml` in the final git
  repo — replace the `<user>` placeholder at publish time, nowhere else.
- Validate XML is well-formed after edits (open in a parser / `python -c
  "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])"
  ollama-intel-gpu.xml`).

## 7. Definition of done

- `docker build` passes; `test-api.sh` passes against the built image.
- README + CHANGELOG updated for any version bump or behaviour change.
- No secrets/diffs to `.env`, `*.tgz`, `*.log` (all git-ignored).
- `git status` clean of unintended files; one focused commit per change.
