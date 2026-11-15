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



1. **MinIO:** Provides local S3-compatible object storage for Kubernetes backups.
2. **Bootstrap:** Installs Argo CD in the new Kubernetes cluster so it can automatically deploy applications from Git.

### 3. Tell your laptop the host names

make host

### 4. Set up Vault

make vault

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
