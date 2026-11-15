We are using **KVM + libvirt + Terraform** to create 3 Ubuntu virtual machines on your ThinkPad (1 Kubernetes control-plane + 2 worker nodes).

Then we use **Ansible to install RKE2 Kubernetes** on those VMs and Argo CD for GitOps deployment of our Hospital DevOps project.

# Phase 3: self-managed Kubernetes platform (RKE2 + GitOps)

### 0. One-time setup on your laptop (Ubuntu or Debian shown)

```bash
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients genisoimage make python3 ansible
sudo usermod -aG libvirt,kvm "$USER"        # then log out and log in again
ssh-keygen -t ed25519                       # only if you have no ~/.ssh/id_ed25519
```

Also install Terraform (https://developer.hashicorp.com/terraform/install). You already have kubectl, helm and Docker from Phase 1 and 2.
Check before going on:

```bash
ls /dev/kvm                                  # must exist (turn on virtualization in the BIOS if not)
virsh -c qemu:///system list --all           # must work without sudo
nproc; free -h                               # CPU threads and RAM (about 20 GB RAM is needed for the VMs)
docker compose version
```

The old k3d cluster is not needed any more. If it still runs: `k3d cluster delete --all`.

### 1. Get the files and go to the folder

```bash
git pull
cd deploy/phase3
```

### 2. Build everything

```bash
make up
```

The first time it stops right away after creating `minio/.env`. Open that file, set a password, run `make up` again. It then does, in order:

1. **MinIO** starts on your laptop (backup storage).
2. **Terraform** downloads the Ubuntu image and creates 3 VMs (about 5 minutes the first time).
3. **Ansible** installs RKE2 on them and writes `deploy/phase3/kubeconfig` (about 5 to 10 minutes).
4. **bootstrap.sh** installs Argo CD and prints its password. Save it.

The same without make (if you prefer):

```bash
cd terraform && terraform init && terraform apply && cd ..
cd ansible && ansible-playbook site.yml && cd ..
./scripts/bootstrap.sh
```

### 3. Tell your laptop the host names

```bash
make hosts          # prints the line and the command to add it to /etc/hosts
```

All sites share one address (10.10.10.200, given by MetalLB to Traefik).

### 4. Set up Vault

```bash
make vault
```

Waits for the Vault pod, initialises and unseals it, creates the passwords and prints your logins (also saved in `.vault-secrets.txt`).
Until this is done the hospital pods wait for their secret. That is normal.

### 5. Wait and watch

Argo CD installs about 18 things. Give it 10 to 20 minutes (more on the first run, many images).

```bash
make status         # nodes should be Ready, applications Synced and Healthy
```

If an app shows "Degraded" for a few minutes at the start, wait. They retry by themselves until the tools they depend on are up.

### 6. Open the sites

| Site                     | Address                                                   | Login                                                                                                                                             |
| ------------------------ | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Hospital A / B           | http://hospital-a.test , http://hospital-b.test           | `admin@hospital-a.example` / `admin@hospital-b.example`, password in `.vault-secrets.txt`                                                   |
| Argo CD                  | http://argocd.test                                        | admin, password printed by bootstrap (or `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d`) |
| Grafana                  | http://grafana.test                                       | admin, password in `.vault-secrets.txt`. Open the hospital dashboard, Explore > Loki for logs                                                   |
| Prometheus, Alertmanager | http://prometheus.test , http://alertmanager.test         | none                                                                                                                                              |
| Vault                    | http://vault.test                                         | token in `.vault-init.json` (`root_token`)                                                                                                    |
| so                       | https://rancher.test (accept the self-signed certificate) | password: `kubectl -n cattle-system get secret bootstrap-secret -o go-template='{{.data.bootstrapPassword\|base64decode}}{{"\n"}}'`              |
| MinIO                    | http://localhost:9001                                     | the login in `minio/.env`                                                                                                                       |
