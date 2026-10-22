#!/usr/bin/env bash
# Verify the observability layer end to end:
#   Prometheus is scraping every money-transfer pod, the SLO rules are loaded and
#   producing data, and Grafana has the SLO dashboard.
set -euo pipefail

PROM_PORT=9090
GRAFANA_PORT=3000
NS=monitoring

kubectl -n "$NS" port-forward svc/kube-prometheus-stack-prometheus "${PROM_PORT}:9090" >/dev/null 2>&1 &
prom_pid=$!
kubectl -n "$NS" port-forward svc/kube-prometheus-stack-grafana "${GRAFANA_PORT}:80" >/dev/null 2>&1 &
graf_pid=$!

# Steady background traffic through the gateway: rates need requests *during*
# the window, otherwise every ratio is 0/0.
gw_svc=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-name=public,gateway.envoyproxy.io/owning-gateway-namespace=gateway -o name | head -n1)
kubectl -n envoy-gateway-system port-forward "$gw_svc" 8090:80 >/dev/null 2>&1 &
gw_pid=$!
(
  while true; do
    curl -s -o /dev/null -H 'Content-Type: application/json' -d '{"amount": "100"}' http://localhost:8090/api/quote || true
    sleep 0.5
  done
) &
traffic_pid=$!
trap 'kill $prom_pid $graf_pid $gw_pid $traffic_pid 2>/dev/null || true' EXIT

query() {
  curl -fsS --get "http://localhost:${PROM_PORT}/api/v1/query" --data-urlencode "query=$1" | jq -r '.data.result'
}

wait_for() { # description, command...
  local what=$1; shift
  for _ in $(seq 1 40); do
    if "$@" >/dev/null 2>&1; then echo "  ok: $what"; return 0; fi
    sleep 6
  done
  echo "  FAILED: $what" >&2
  return 1
}

scraped_pods() {
  local up desired
  up=$(query 'sum(up{job="money-transfer"} == 1)' | jq -r '.[0].value[1] // "0"')
  desired=$(kubectl -n money-transfer get deploy money-transfer -o jsonpath='{.status.readyReplicas}')
  [[ "$up" -ge 1 && "$up" == "$desired" ]]
}
rules_loaded() {
  curl -fsS "http://localhost:${PROM_PORT}/api/v1/rules" \
    | jq -e '[.data.groups[].name] | index("money-transfer-slo-alerts")' >/dev/null
}
sli_has_data() {
  # Needs at least two scrapes after traffic; the zero-error case must read 0, not "no data".
  [[ "$(query 'slo:availability_errors:ratio_rate5m' | jq -r '.[0].value[1] // "none"')" == "0" ]]
}
dashboard_loaded() {
  curl -fsS -u admin:prom-operator "http://localhost:${GRAFANA_PORT}/api/dashboards/uid/money-transfer-slo" \
    | jq -e '.dashboard.title' >/dev/null
}

echo "==> Checking monitoring"
wait_for "Prometheus is scraping every ready money-transfer pod" scraped_pods
wait_for "SLO rules are loaded" rules_loaded
wait_for "availability SLI is recording (0 errors -> 0, not empty)" sli_has_data
wait_for "Grafana has the SLO dashboard" dashboard_loaded
echo "==> Monitoring checks passed"
