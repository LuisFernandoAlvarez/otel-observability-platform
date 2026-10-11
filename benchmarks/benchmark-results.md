# Benchmark comparison

| Scenario | p99 latency | CPU overhead | Memory increase | Error rate |
| --- | ---: | ---: | ---: | ---: |
| Baseline (no OTel) | 180 ms | 0% | 0 MB | 0.4% |
| Instrumented (OTel) | 260 ms | 12.5% | +128 MB | 0.6% |
| Delta | +80 ms | +12.5% | +128 MB | +0.2% |

This is an example profile from a representative load test. The exact values will vary by environment and service mix.

## Recommended benchmark procedure

1. Run the service stack without OTel exporter enabled.
2. Execute the k6 script with the same parameters.
3. Capture p99 latency, CPU, memory, and errors.
4. Repeat with OTel enabled and same workload.
5. Compare deltas and validate the trade-off against service SLOs.

Command:

```bash
k6 run benchmarks/k6-load.js
```
