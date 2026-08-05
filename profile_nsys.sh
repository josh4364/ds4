#!/usr/bin/env bash
# profile_nsys.sh — Automated Nsight Systems CLI trace for active decode generation

set -e

PORT=8000
DURATION=${1:-10}
OUTPUT_PREFIX="nsys_trace_longctx"

echo "=== Starting ds4-server under nsys profile ==="
nsys profile --trace=cuda,nvtx -o "$OUTPUT_PREFIX" --force-overwrite true ./start-ds4-server.sh > nsys_server.log 2>&1 &
SERVER_PID=$!

cleanup() {
    echo "Stopping ds4-server (PID: $SERVER_PID)..."
    kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

echo "Waiting for ds4-server to listen on port $PORT..."
until grep -q "listening on http://0.0.0.0:$PORT" nsys_server.log 2>/dev/null; do
    sleep 1
done
echo "Server online!"

echo "Sending long-context benchmark query..."
curl -s http://localhost:$PORT/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "ds4",
    "messages": [
      {"role": "user", "content": "Write a long technical paper on deep learning system performance profiling on GPU clusters."}
    ],
    "max_tokens": 150
  }' > /dev/null

echo "Waiting ${DURATION}s for trace collection..."
sleep "$DURATION"

echo ""
echo "=== Nsys Top GPU Kernel Summary Report ==="
nsys stats --report gputrace "${OUTPUT_PREFIX}.nsys-rep" | head -n 30 || true
