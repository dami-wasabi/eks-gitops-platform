#!/usr/bin/env bash
# Wait until every Argo CD Application is Synced and Healthy, or time out.
set -euo pipefail

TIMEOUT="${TIMEOUT:-600}"
EXPECTED=(envoy-gateway metrics-server kube-prometheus-stack gateway money-transfer)
deadline=$(( $(date +%s) + TIMEOUT ))

echo "==> Waiting up to ${TIMEOUT}s for Argo CD applications"
while true; do
  apps_json=$(kubectl -n argocd get applications -o json)
  echo "$apps_json" | jq -r '.items[] | "  \(.metadata.name): \(.status.sync.status // "-") / \(.status.health.status // "-")"'

  ready=true
  for app in "${EXPECTED[@]}"; do
    state=$(echo "$apps_json" | jq -r --arg n "$app" \
      '.items[] | select(.metadata.name == $n) | "\(.status.sync.status)/\(.status.health.status)"')
    [[ "$state" == "Synced/Healthy" ]] || ready=false
  done

  if $ready; then
    echo "==> All applications Synced and Healthy"
    exit 0
  fi
  if (( $(date +%s) > deadline )); then
    echo "==> Timed out. Application details:" >&2
    kubectl -n argocd get applications -o yaml | grep -A20 "conditions:\|operationState:" >&2 || true
    exit 1
  fi
  sleep 15
done
