# Phase 3 runbook: drills and everyday commands

Every command assumes `cd deploy/phase3` and `export KUBECONFIG=$PWD/kubeconfig` (the Makefile does this for make targets).
Write the result of each drill in your notes. That is the CV material.

## 1. Where does the cluster stand?
```bash
kubectl get nodes
kubectl -n argocd get applications
kubectl get pods -A | grep -v Running | grep -v Completed
```

## 2. Alert drill (Prometheus, Alertmanager)
```bash
kubectl -n hospital-a scale deploy/web --replicas=0     # Argo CD ignores replicas, so this stays
# wait 1 to 2 minutes: http://alertmanager.test shows HospitalWebDown
kubectl -n hospital-a scale deploy/web --replicas=2
```

## 3. Backup and restore of the database (Phase 2 CronJob, consistent copy)
The Phase 2 CronJob `sql-backup` writes `HospitalDB_<day>.bak` files to the `backups` volume (mounted at `/backups` in the db pod).
```bash
kubectl -n hospital-a create job --from=cronjob/sql-backup backup-now
kubectl -n hospital-a logs job/backup-now                 # "backup finished: HospitalDB_....bak"
kubectl -n hospital-a exec db-0 -- ls -l /backups
```
Check that a backup file is valid (two steps, so no quoting trouble):
```bash
kubectl -n hospital-a exec -it db-0 -- bash
/opt/mssql-tools18/bin/sqlcmd -C -S localhost -U sa -P "$MSSQL_SA_PASSWORD" -Q "RESTORE VERIFYONLY FROM DISK = N'/backups/<file>.bak'"
```
A real restore (drill): in the same shell run `RESTORE DATABASE [HospitalDB] FROM DISK = N'/backups/<file>.bak' WITH REPLACE`.

## 4. Velero: off-cluster copy to MinIO
```bash
kubectl apply -f - <<'EOF'
apiVersion: velero.io/v1
kind: Backup
metadata: {name: manual-hospital-a, namespace: velero}
spec: {includedNamespaces: [hospital-a], ttl: 72h}
EOF
kubectl -n velero get backups          # Phase should become Completed
```
Restore after deleting the namespace's data:
```bash
kubectl apply -f - <<'EOF'
apiVersion: velero.io/v1
kind: Restore
metadata: {name: restore-hospital-a, namespace: velero}
spec: {backupName: manual-hospital-a}
EOF
```
Look in the MinIO console (http://localhost:9001, bucket `velero`) to see the files. Note: the live SQL data volume is only crash-consistent. The `.bak` files from the Phase 2 CronJob are the safe copy.

## 5. etcd snapshot and restore (the cluster database)
On the server VM (`ssh ops@10.10.10.11`):
```bash
sudo rke2 etcd-snapshot save --name drill
sudo rke2 etcd-snapshot ls
sudo systemctl stop rke2-server
sudo rke2 server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/rke2/server/db/snapshots/<file>
sudo systemctl start rke2-server
```
Automatic snapshots run every 6 hours (kept: 10).

## 6. RKE2 upgrade drill
```bash
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/crd.yaml
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/latest/download/system-upgrade-controller.yaml
kubectl apply -f gitops/upgrade/plan.yaml
kubectl get nodes -w
```
The controller upgrades the server first, then the workers, one at a time. Check that Rancher supports the new Kubernetes version first.

## 7. Kyverno: see it work, then enforce
```bash
kubectl get policyreport -A                              # what the policies found (Audit mode)
kubectl run tagtest --image=nginx:latest -n default      # reported by disallow-latest-tag
kubectl delete pod tagtest -n default
```
To block instead of report: in `gitops/policies/*.yaml` change `validationFailureAction: Audit` to `Enforce`, commit, push. Argo CD applies it (a change made by hand with kubectl is reverted by Argo CD on purpose).
Signature check: after the first release, the web image is `ghcr.io/obaidkhan19/hospital-web:sha-...`. Run an unsigned image of the same name in `hospital-a` and look at the policy report.

## 8. Vault after a restart
Vault is sealed after every VM restart: `make vault` unseals it. Secrets stay (they are on its disk).
Change a password: `kubectl -n vault exec -it vault-0 -- sh`, then `export VAULT_TOKEN=<root_token>` and `vault kv put secret/hospital-a ...`.
External Secrets refreshes the Kubernetes Secret within an hour (or restart the ExternalSecret).

## 9. Rancher
Open https://rancher.test, use the bootstrap password from the README, set your own password. The "local" cluster is your RKE2 cluster: browse nodes, workloads, logs and roles.

## 10. Go from 1 to 3 control-plane nodes
Only on a fresh cluster (see README, "Switches and growing"): `server_count = 3`, set `rke2_api_address` to a fixed address first, `make destroy`, `make up`. Needs about 8 GB more RAM.
