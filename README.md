# otel-observability-platform

This repository demonstrates a two-service distributed application instrumented with OpenTelemetry for traces, metrics, and logs. It includes:

- service-a: HTTP API that calls service-b and stores data in PostgreSQL
- service-b: downstream service with DB access and business processing
- OTel Collector configured for OTLP, batching, Prometheus scraping, and Jaeger export
- Prometheus + Grafana for metrics and dashboards
- Jaeger UI for distributed traces
- structured JSON logs with trace_id/span_id
- k6 benchmark script and comparative results documentation

Architecture:

- Service A -> Service B (HTTP)
- Service A -> PostgreSQL
- Service B -> PostgreSQL
- Service A/B -> OTLP -> OTel Collector -> Jaeger + Prometheus + logs

## Quick start

```bash
docker compose up --build
```

Then:

- Service A: http://localhost:8001
- Service B: http://localhost:8002
- Jaeger UI: http://localhost:16686
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/admin)

## Example request

```bash
curl -X POST http://localhost:8001/process \
  -H 'Content-Type: application/json' \
  -d '{"customer":"alice","item":"laptop","quantity":2,"amount":1200.00}'
```

This triggers the service-a business flow, writes to PostgreSQL, calls service-b via HTTP, and emits traces/metrics/logs through the collector.

## Observability responsibilities

- Traces: OTLP exporter to OTel Collector -> Jaeger
- Metrics: OTel metric pipeline -> Prometheus endpoint scraped by Prometheus
- Logs: structured JSON with trace_id/span_id and stdout output; collector can also route to cloud logging services when configured

## Cloud deployment notes

- GCP: deploy the collector and services to Cloud Run or GKE, with workload identity and OTLP endpoints
- AWS: deploy to ECS Fargate; configure collector with AWS EMF exporter for CloudWatch Logs and X-Ray/Tempo backends

## Benchmark

Use:

```bash
k6 run benchmarks/k6-load.js
```

See `benchmarks/benchmark-results.md` for an example comparison between baseline and instrumented runs.
