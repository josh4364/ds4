#!/usr/bin/env bash
set -euo pipefail

# Find script directory
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd -- "$ROOT"

# Configuration defaults for host, port, context window, default temperature, MTP model, MTP draft tokens, and KV disk dir
HOST="${DS4_HOST:-${HOST:-0.0.0.0}}"
PORT="${DS4_PORT:-${PORT:-8000}}"
CTX="${DS4_CTX:-${CTX:-32768}}"
TEMP="${DS4_TEMP:-${TEMP:-0}}"
MTP_MODEL="${DS4_MTP_MODEL:-${MTP_MODEL:-$ROOT/gguf/DeepSeek-V4-Flash-DSpark-support-0731.gguf}}"
MTP_DRAFT="${DS4_MTP_DRAFT:-${MTP_DRAFT:-2}}"
KV_DIR="${DS4_KV_DIR:-${KV_DIR:-$ROOT/kv-cache}}"

# Ensure ds4-server executable exists
if [[ ! -x "./ds4-server" ]]; then
    echo "Error: ./ds4-server binary not found or not executable in $ROOT" >&2
    echo "Please build ds4-server first (e.g. run 'make cuda-spark')." >&2
    exit 1
fi

# Ensure KV disk directory exists
mkdir -p "$KV_DIR"

# Enable CUDA SplitKV speculative decoding, default temperature 0, and CPU thread tuning
export DS4_CUDA_SPLITKV_SPEC="${DS4_CUDA_SPLITKV_SPEC:-1}"
export DS4_DEFAULT_TEMPERATURE="${DS4_DEFAULT_TEMPERATURE:-0.0}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-8}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-8}"

MTP_ARGS=(--mtp-draft "$MTP_DRAFT")
if [[ "${DS4_ENABLE_DSPARK:-0}" == "1" ]] && [[ -f "$MTP_MODEL" ]]; then
    MTP_ARGS=(--dspark --mtp "$MTP_MODEL" --mtp-draft "$MTP_DRAFT")
    echo "Enabling DSpark & MTP speculative decoding (draft tokens: ${MTP_DRAFT}) with model: $MTP_MODEL"
else
    echo "Enabling native CUDA SplitKV speculative decoding (draft tokens: ${MTP_DRAFT})."
fi

echo "Starting ds4-server bound to ${HOST}:${PORT} with context size ${CTX}, default temp ${TEMP} (KV cache dir: ${KV_DIR})..."
exec ./ds4-server --ctx "$CTX" --host "$HOST" --port "$PORT" --temp "$TEMP" --kv-disk-dir "$KV_DIR" "${MTP_ARGS[@]}" "$@"
