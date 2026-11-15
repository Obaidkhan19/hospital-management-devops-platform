#!/usr/bin/env bash
# bootstrap.sh - the only manual install on the new cluster: Argo CD.
# Then root-app.yaml tells Argo CD to install everything else from Git (gitops/apps/).
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/kubeconfig"

helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update argo >/dev/null

helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace \
  -f gitops/bootstrap/values-argocd.yaml --wait --timeout 10m

kubectl apply -f gitops/bootstrap/root-app.yaml

echo
echo "Argo CD is installed and is now installing the platform. Watch it with: make status"
echo "Argo CD login: user admin, password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
echo
