#!/bin/bash

# Script to run k6 benchmarks and compare baseline vs instrumented
# Prerequisites: k6 installed

set -e

BASELINE_RESULTS="benchmarks/results-baseline.json"
INSTRUMENTED_RESULTS="benchmarks/results-instrumented.json"
COMPARISON_REPORT="benchmarks/comparison-report.txt"

echo "=== OTel Overhead Benchmark ==="

echo "\n1. Running baseline (no OTel) benchmark..."
k6 run benchmarks/k6-load.js \
  --out json=$BASELINE_RESULTS \
  --summary-export=benchmarks/summary-baseline.json

echo "\n2. Waiting 30 seconds before instrumented run..."
sleep 30

echo "\n3. Running instrumented (with OTel) benchmark..."
k6 run benchmarks/k6-load.js \
  --out json=$INSTRUMENTED_RESULTS \
  --summary-export=benchmarks/summary-instrumented.json

echo "\n4. Comparing results..."

cat > $COMPARISON_REPORT << 'EOF'
=== Benchmark Comparison: Baseline vs Instrumented ===

EOF

echo "Baseline results:" >> $COMPARISON_REPORT
jq '.metrics[] | select(.type == "trend") | {name: .name, avg: .values.avg, p95: .values."p(95)", p99: .values."p(99)"}' $BASELINE_RESULTS >> $COMPARISON_REPORT

echo "\nInstrumented results:" >> $COMPARISON_REPORT
jq '.metrics[] | select(.type == "trend") | {name: .name, avg: .values.avg, p95: .values."p(95)", p99: .values."p(99)"}' $INSTRUMENTED_RESULTS >> $COMPARISON_REPORT

echo "\n=== Results saved to $COMPARISON_REPORT ==="
cat $COMPARISON_REPORT
