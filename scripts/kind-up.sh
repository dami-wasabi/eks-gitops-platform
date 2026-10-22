#!/usr/bin/env bash
# Bring up the whole platform on a local kind cluster:
#   kind cluster -> Argo CD -> Argo CD syncs everything else from Git -> smoke test.
#
# Usage: scripts/kind-up.sh
#   REVISION=<git sha or branch>  deploy that revision instead of main (used by CI)
set -euo pipefail
cd "$(dirname "$0")/.."

ARGOCD_CHART_VERSION="10.10.5"
CLUSTER_NAME="gitops"
REVISION="${REVISION:-main}"

for tool in kind kubectl helm jq curl; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "==> Creating kind cluster '$CLUSTER_NAME'"
  kind create cluster --config kind/cluster.yaml --wait 120s
fi

echo "==> Installing Argo CD (chart $ARGOCD_CHART_VERSION)"
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null
helm upgrade --install argocd argo/argo-cd \
  --version "$ARGOCD_CHART_VERSION" \
  --namespace argocd --create-namespace \
  --values bootstrap/argocd-values.yaml \
  --wait --timeout 10m

if [[ "$REVISION" == "main" ]]; then
  echo "==> Applying the root app-of-apps (tracks main)"
  kubectl apply -f bootstrap/root-app.yaml
else
  # Pin every Application to the commit under test so CI checks this change,
  # not whatever is currently on main.
  echo "==> Applying cluster apps pinned to $REVISION"
  kubectl kustomize gitops/clusters/kind \
    | sed "s/targetRevision: main/targetRevision: ${REVISION}/" \
    | kubectl apply -f -
fi

scripts/wait-for-apps.sh
scripts/smoke-test.sh

cat <<MSG

Platform is up. Useful next steps:
  Argo CD UI:   kubectl -n argocd port-forward svc/argocd-server 8081:80   -> http://localhost:8081
  Password:     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
  The app:      scripts/smoke-test.sh --keep   (leaves a port-forward on http://localhost:8080)
  Tear down:    kind delete cluster --name $CLUSTER_NAME
MSG
