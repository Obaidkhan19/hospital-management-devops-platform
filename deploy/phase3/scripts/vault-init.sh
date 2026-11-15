#!/usr/bin/env bash
# vault-init.sh - makes Vault usable. Safe to run any time:
#   new cluster : initialise Vault, unseal it, create the secrets engine, the login for External Secrets,
#                 and the passwords (hospital-a, hospital-b, grafana, velero/MinIO)
#   restart     : just unseal (Vault is sealed again after every VM restart)
# The unseal key and root token are kept in .vault-init.json, the generated passwords in
# .vault-secrets.txt. Both are git-ignored. One key share is a lab shortcut; production uses 5 shares, 3 needed.
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/kubeconfig"
INIT=.vault-init.json
SECRETS=.vault-secrets.txt

echo "Waiting for the vault-0 pod (Argo CD creates it) ..."
for _ in $(seq 1 120); do
  kubectl -n vault get pod vault-0 >/dev/null 2>&1 && break
  sleep 10
done
kubectl -n vault wait --for=condition=Ready pod/vault-0 --timeout=600s

vault() { kubectl -n vault exec -i vault-0 -- env VAULT_TOKEN="${TOKEN:-}" vault "$@"; }
field() { python3 -c "import sys,json; print(json.load(sys.stdin)['$1'])"; }
gen()   { python3 -c "import secrets,string; a=string.ascii_letters+string.digits; print(''.join(secrets.choice(a) for _ in range(18))+'aA1!')"; }

STATUS=$(kubectl -n vault exec vault-0 -- vault status -format=json 2>/dev/null || true)
INITIALIZED=$(echo "$STATUS" | field initialized)
FRESH=false

if [ "$INITIALIZED" = "False" ]; then
  [ -f "$INIT" ] && mv "$INIT" "$INIT.old"
  kubectl -n vault exec vault-0 -- vault operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT"
  chmod 600 "$INIT"
  FRESH=true
elif [ ! -f "$INIT" ]; then
  echo "Vault is already initialised but $INIT is missing. Destroy and rebuild the cluster (make destroy) to start clean." >&2
  exit 1
fi

TOKEN=$(field root_token < "$INIT")
KEY=$(python3 -c "import json; print(json.load(open('$INIT'))['unseal_keys_b64'][0])")

STATUS=$(kubectl -n vault exec vault-0 -- vault status -format=json 2>/dev/null || true)
if [ "$(echo "$STATUS" | field sealed)" = "True" ]; then
  vault operator unseal "$KEY" >/dev/null
  echo "Vault unsealed."
fi

if [ "$FRESH" = "true" ]; then
  echo "Configuring Vault ..."
  vault secrets enable -path=secret kv-v2

  # what External Secrets may read
  vault policy write external-secrets - <<'EOF'
path "secret/data/*"     { capabilities = ["read"] }
path "secret/metadata/*" { capabilities = ["read", "list"] }
EOF

  # Kubernetes login: the External Secrets service account proves who it is to Vault
  vault auth enable kubernetes
  vault write auth/kubernetes/config kubernetes_host="https://kubernetes.default.svc:443"
  vault write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces=external-secrets \
    policies=external-secrets ttl=1h

  # passwords: generated, never in Git. Set HOSPITAL_ADMIN_PASSWORD to choose the admin password yourself.
  DB_A=$(gen); DB_B=$(gen); GRAFANA=$(gen)
  ADMIN_A=${HOSPITAL_ADMIN_PASSWORD:-$(gen)}
  ADMIN_B=${HOSPITAL_ADMIN_PASSWORD:-$(gen)}
  vault kv put secret/hospital-a MSSQL_SA_PASSWORD="$DB_A" Seed__AdminPassword="$ADMIN_A" >/dev/null
  vault kv put secret/hospital-b MSSQL_SA_PASSWORD="$DB_B" Seed__AdminPassword="$ADMIN_B" >/dev/null
  vault kv put secret/grafana admin-user=admin admin-password="$GRAFANA" >/dev/null

  # MinIO login for Velero (same file docker compose uses)
  # shellcheck disable=SC1091
  . minio/.env
  CLOUD=$'[default]\naws_access_key_id='"$MINIO_ROOT_USER"$'\naws_secret_access_key='"$MINIO_ROOT_PASSWORD"
  vault kv put secret/velero cloud="$CLOUD" >/dev/null

  umask 077
  {
    echo "Hospital A  admin@hospital-a.example  $ADMIN_A"
    echo "Hospital B  admin@hospital-b.example  $ADMIN_B"
    echo "Grafana     admin                     $GRAFANA"
  } > "$SECRETS"
  echo
  echo "Done. Logins are saved in deploy/phase3/$SECRETS (not committed):"
  cat "$SECRETS"
fi
echo "Vault root token and unseal key: deploy/phase3/$INIT"
