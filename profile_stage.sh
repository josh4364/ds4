#!/usr/bin/env bash
# profile_stage.sh — Automated microsecond stage timing breakdown for long-context generation

set -e

LOG_FILE="profile_stage.log"
PORT=8000
MAX_TOKENS=${1:-200}

echo "=== Starting ds4-server with DS4_CUDA_DECODE_STAGE_PROFILE=1 ==="
DS4_CUDA_DECODE_STAGE_PROFILE=1 ./start-ds4-server.sh > "$LOG_FILE" 2>&1 &
SERVER_PID=$!

cleanup() {
    echo "Stopping ds4-server (PID: $SERVER_PID)..."
    kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for ds4-server to listen on port $PORT..."
until grep -q "listening on http://0.0.0.0:$PORT" "$LOG_FILE" 2>/dev/null; do
    sleep 1
done
echo "Server online!"

echo "Sending long-context prompt benchmark ($MAX_TOKENS tokens)..."
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"ds4\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"Write a comprehensive detailed technical guide on optimizing CUDA kernels for NVIDIA Grace Blackwell GB10 GPUs, including warp shuffles, memory alignment, and SplitKV decode attention.\"}
    ],
    \"max_tokens\": $MAX_TOKENS
  }" > /dev/null

echo ""
echo "=== Stage Timing Breakdown Summary (from $LOG_FILE) ==="
grep -E "chat ctx=|decode_stage|t/s" "$LOG_FILE" | tail -n 25 || true
