We are using **KVM + libvirt + Terraform** to create 3 Ubuntu virtual machines (1 Kubernetes control-plane + 2 worker nodes).
Video = https://youtu.be/a78X8-VCAD4
Images in images folder 

 install Terraform (https://developer.hashicorp.com/terraform/install).

sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients genisoimage make python3 ansible
sudo usermod -aG libvirt,kvm "$USER"        # then log out and log in again
ssh-keygen -t ed25519                       # only if you have no ~/.ssh/id_ed25519


1. **MinIO** starts on your laptop (backup storage).
2. **Terraform** downloads the Ubuntu image and creates 3 VMs (about 5 minutes the first time).
3. **Ansible** installs RKE2 on them and writes `deploy/phase3/kubeconfig` (about 5 to 10 minutes).
4. **bootstrap.sh** installs Argo CD and prints its password. Save it.
5. **MinIO:** Provides local S3-compatible object storage for Kubernetes backups.
6. **Bootstrap:** Installs Argo CD in the new Kubernetes cluster so it can automatically deploy applications from Git.


make up

make host


make vault

make down  = delete vm

make wipe = delete all

sudo virsh -c qemu:///system list --all
docker ps -a

virsh -c qemu:///system list --all
docker ps -a
free -h ; df -h /

### 5. Wait and watch

make status


kubectl get pods -A -w = -a is all

kubectl get nodes



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
