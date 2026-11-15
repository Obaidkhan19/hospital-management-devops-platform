We are using **KVM + libvirt + Terraform** to create 3 Ubuntu virtual machines on your ThinkPad (1 Kubernetes control-plane + 2 worker nodes).

Then we use **Ansible to install RKE2 Kubernetes** on those VMs and Argo CD for GitOps deployment of our Hospital DevOps project.

# Phase 3: self-managed Kubernetes platform (RKE2 + GitOps)

 install Terraform (https://developer.hashicorp.com/terraform/install).

sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients genisoimage make python3 ansible
sudo usermod -aG libvirt,kvm "$USER"        # then log out and log in again
ssh-keygen -t ed25519                       # only if you have no ~/.ssh/id_ed25519

### 2. Build everything

make up

1. **MinIO** starts on your laptop (backup storage).
2. **Terraform** downloads the Ubuntu image and creates 3 VMs (about 5 minutes the first time).
3. **Ansible** installs RKE2 on them and writes `deploy/phase3/kubeconfig` (about 5 to 10 minutes).
4. **bootstrap.sh** installs Argo CD and prints its password. Save it.
5. **MinIO:** Provides local S3-compatible object storage for Kubernetes backups.
6. **Bootstrap:** Installs Argo CD in the new Kubernetes cluster so it can automatically deploy applications from Git.

### 3. Tell your laptop the host names

make host

### 4. Set up Vault

make vault



make down  = delete vm

make wipe = delete all

### 5. Wait and watch

make status

Argo CD installs 10 to 20 minutes

kubectl get pods -A -w = -a is all

kubectl get nodes

### 6. Open the sites

ARGO CD PASS =

export KUBECONFIG="$PWD/deploy/phase3/kubeconfig"

kubectl -n argocd get secret argocd-initial-admin-secret
  -o jsonpath='{.data.password}' | base64 -d
echo

| Site                     | Address                                                   | Login                                                                                                                                |
| ------------------------ | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Hospital A / B           | http://hospital-a.test , http://hospital-b.test           | `admin@hospital-a.example` / `admin@hospital-b.example`, password in `.vault-secrets.txt`                                      |
| Argo CD                  | http://argocd.test                                        | admin, password printed by bootstrap                                                                                                 |
| Grafana                  | http://grafana.test                                       | admin, password in `.vault-secrets.txt`. Open the hospital dashboard, Explore > Loki for logs                                      |
| Prometheus, Alertmanager | http://prometheus.test , http://alertmanager.test         | none                                                                                                                                 |
| Vault                    | http://vault.test                                         | token in `.vault-init.json` (`root_token`)                                                                                       |
| Rancher                  | https://rancher.test (accept the self-signed certificate) | password: `kubectl -n cattle-system get secret bootstrap-secret -o go-template='{{.data.bootstrapPassword\|base64decode}}{{"\n"}}'` |
| MinIO                    | http://localhost:9001                                     | the login in cat deploy/phase3/minio/.env                                                                                           |







# Commands: is my project running properly?

Run from `deploy/phase3`. `make status` runs the most useful ones at once.

## The 3 commands (also weeks later)

| Command         | What it does                                                                                  |
| --------------- | --------------------------------------------------------------------------------------------- |
| `make up`     | builds everything: MinIO, 3 VMs, RKE2, Argo CD (Argo then installs all apps, about 10-15 min) |
| `make vault`  | unseals Vault / creates the secrets (needed after every new build or restart)                 |
| `make status` | shows if all is healthy                                                                       |

One-time only: `make hosts` and add the printed line to `/etc/hosts`. Wait about 10 min after `make vault` until `make status` shows all apps `Synced / Healthy`.
Grafana (http://grafana.test) has the dashboard **Hospital Platform Overview** built automatically from Git. Password: `cat .vault-secrets.txt`.

## Kill everything (no RAM or disk used)

| Command                        | Result                                                                              |
| ------------------------------ | ----------------------------------------------------------------------------------- |
| `make down`                  | deletes the VMs and stops MinIO. RAM is free. Next `make up` starts clean.        |
| `make wipe`                  | also deletes MinIO backups, Terraform state and the libvirt pool. Disk is free too. |
| `make stop` / `make start` | only pause / resume the VMs (keeps the cluster, still uses disk)                    |

Check that nothing is left:

```
virsh -c qemu:///system list --all      # no rke2-* VMs
docker ps -a                            # no minio
free -h ; df -h /                       # RAM and disk
```

## Cluster

```
kubectl get nodes -o wide               # 3 nodes, all Ready
kubectl get ns                          # all namespaces
kubectl get pods -A                     # every pod
kubectl get pods -A | grep -v -E 'Running|Completed'   # only problems
kubectl get pods -n hospital-a -o wide  # one namespace, with the node
kubectl get svc,ingress -A              # services and web addresses
kubectl get pvc -A                      # storage
kubectl top nodes ; kubectl top pods -A # CPU / RAM (needs metrics-server, included in RKE2)
kubectl get events -A --sort-by=.lastTimestamp | tail -20
```

## One pod in trouble

```
kubectl describe pod <pod> -n <ns>      # why it does not start (see Events at the bottom)
kubectl logs <pod> -n <ns> --tail=50    # its log
kubectl logs <pod> -n <ns> --previous   # log before the last crash
```

## Argo CD (GitOps)

```
kubectl -n argocd get applications      # SYNC and HEALTH per app
kubectl -n argocd get app <name> -o jsonpath='{.status.conditions}'   # why an app is stuck
```

UI: http://argocd.test (user `admin`, password printed by `make up`).

## Platform parts

```
kubectl get certificate -A                              # cert-manager
kubectl get clustersecretstore,externalsecret -A        # Vault -> secrets (STATUS must be Ready / SecretSynced)
kubectl -n vault exec vault-0 -- vault status           # Sealed must be false
kubectl get cpol                                        # Kyverno policies
kubectl get policyreport -A | head                      # Kyverno findings
kubectl -n velero get backups,schedules                 # backups
kubectl get ipaddresspool -A                            # MetalLB
```

## VMs and network (laptop)

```
virsh -c qemu:///system list --all
virsh -c qemu:///system net-list --all
ssh ops@10.10.10.11                     # into the control-plane VM
sudo journalctl -u rke2-server -f       # RKE2 log (on that VM)
```

## Quick test of the web apps

```
curl -I http://hospital-a.test ; curl -I http://hospital-b.test
```
