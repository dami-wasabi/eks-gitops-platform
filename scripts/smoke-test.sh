#!/usr/bin/env bash
# Call the app end to end through the Gateway: client -> Envoy proxy -> HTTPRoute -> Service -> Pod.
# Usage: scripts/smoke-test.sh [--keep]   (--keep leaves the port-forward running)
set -euo pipefail

HOST_HEADER="${HOST_HEADER:-money-transfer.local}"
LOCAL_PORT=8080

svc=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-name=public,gateway.envoyproxy.io/owning-gateway-namespace=gateway \
  -o name | head -n1)
[[ -n "$svc" ]] || { echo "Envoy proxy service for Gateway 'public' not found" >&2; exit 1; }

kubectl -n envoy-gateway-system port-forward "$svc" "${LOCAL_PORT}:80" >/dev/null 2>&1 &
pf_pid=$!
[[ "${1:-}" == "--keep" ]] || trap 'kill $pf_pid 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
  curl -fsS -H "Host: $HOST_HEADER" "http://localhost:${LOCAL_PORT}/healthz" >/dev/null 2>&1 && break
  sleep 2
done

echo "==> GET /healthz"
curl -fsS -H "Host: $HOST_HEADER" "http://localhost:${LOCAL_PORT}/healthz"
echo

echo "==> POST /api/quote {\"amount\": \"100\"}"
quote=$(curl -fsS -H "Host: $HOST_HEADER" -H 'Content-Type: application/json' \
  -d '{"amount": "100"}' "http://localhost:${LOCAL_PORT}/api/quote")
echo "$quote"
[[ "$(echo "$quote" | jq -r .total_to_pay)" == "102.00" ]] || { echo "unexpected quote" >&2; exit 1; }

echo "==> Smoke test passed"
if [[ "${1:-}" == "--keep" ]]; then
  echo "App available at http://localhost:${LOCAL_PORT}; port-forward pid ${pf_pid}"
fi
