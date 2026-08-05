#!/usr/bin/env bash
# benchmark_sweep.sh — Automated parameter sweep for SplitKV tuning & throughput comparison

set -e

RESULTS_FILE="sweep_results.log"
PORT=8000
MAX_TOKENS=250

echo "=== SplitKV Benchmark Parameter Sweep ===" | tee "$RESULTS_FILE"
echo "Timestamp: $(date)" | tee -a "$RESULTS_FILE"
echo "--------------------------------------------------------" | tee -a "$RESULTS_FILE"
printf "%-15s %-12s %-12s %-12s\n" "SPLITKV_CHUNK" "Prefill(s)" "Avg (t/s)" "Peak (t/s)" | tee -a "$RESULTS_FILE"
echo "--------------------------------------------------------" | tee -a "$RESULTS_FILE"

CHUNKS=(256 512 1024)

for CHUNK in "${CHUNKS[@]}"; do
    LOG_NAME="sweep_chunk_${CHUNK}.log"
    echo "Testing DS4_CUDA_SPLITKV_CHUNK=${CHUNK}..."
    
    DS4_CUDA_SPLITKV_CHUNK=$CHUNK ./start-ds4-server.sh > "$LOG_NAME" 2>&1 &
    SERVER_PID=$!
    
    until grep -q "listening on http://0.0.0.0:$PORT" "$LOG_NAME" 2>/dev/null; do
        sleep 1
    done
    
    # Run completion query
    curl -s http://localhost:$PORT/v1/chat/completions \
      -H "Content-Type: application/json" \
      -d "{
        \"model\": \"ds4\",
        \"messages\": [
          {\"role\": \"user\", \"content\": \"Write a python program to calculate prime numbers up to 1000 with explanations.\"}
        ],
        \"max_tokens\": $MAX_TOKENS
      }" > /dev/null
    
    # Extract metrics
    PREFILL=$(grep "prompt done" "$LOG_NAME" | tail -n1 | awk '{print $(NF)}' | tr -d 's')
    AVG_TS=$(grep "gen=" "$LOG_NAME" | tail -n1 | sed -n 's/.*avg=\([0-9.]*\) t\/s.*/\1/p')
    PEAK_TS=$(grep "decoding chunk=" "$LOG_NAME" | awk -F'chunk=' '{print $2}' | awk '{print $1}' | sort -nr | head -n1)
    
    printf "%-15s %-12s %-12s %-12s\n" "$CHUNK" "${PREFILL:-N/A}" "${AVG_TS:-N/A}" "${PEAK_TS:-N/A}" | tee -a "$RESULTS_FILE"
    
    kill "$SERVER_PID" 2>/dev/null || true
    sleep 2
done

echo "--------------------------------------------------------" | tee -a "$RESULTS_FILE"
echo "Sweep complete! Results saved to $RESULTS_FILE"
