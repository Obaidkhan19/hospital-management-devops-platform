# Makefile - short names for the Phase 3 commands. Run from deploy/phase3:   make <name>
#   make up        MinIO + VMs + RKE2 + Argo CD   (the whole build)
#   make hosts     prints the line for /etc/hosts
#   make vault     sets up / unseals Vault        (after "make up" and after every start)
#   make status    health check: nodes, apps, problem pods, hospitals, URLs
#   make stop      shut the VMs down (keeps everything)    make start   start them again
#   make destroy   delete the VMs                 make minio-down   stop MinIO
#   make down      delete VMs + stop MinIO (frees all RAM and the VM disks)
#   make wipe      down + delete the MinIO backups and downloaded images (frees ALL disk)
SHELL := /bin/bash
export KUBECONFIG := $(CURDIR)/kubeconfig
VIRSH := virsh -c qemu:///system
HOSTS := 10.10.10.200 hospital-a.test hospital-b.test argocd.test grafana.test prometheus.test alertmanager.test vault.test rancher.test

.PHONY: up minio vms cluster bootstrap vault hosts status stop start destroy minio-down down wipe

up: minio vms cluster bootstrap
	@echo "Next: make hosts (add the line to /etc/hosts), then make vault"

minio:
	@test -f minio/.env || { cp minio/.env.example minio/.env; echo "Created minio/.env. Edit the password in it, then run make up again."; exit 1; }
	cd minio && docker compose up -d

vms:
	terraform -chdir=terraform init -input=false
	terraform -chdir=terraform apply -auto-approve

cluster:
	cd ansible && ansible-playbook site.yml

bootstrap:
	./scripts/bootstrap.sh

vault:
	./scripts/vault-init.sh

hosts:
	@echo "$(HOSTS)"
	@echo "Add it with:  echo '$(HOSTS)' | sudo tee -a /etc/hosts"

status:
	@echo "== Nodes =="; kubectl get nodes -o wide
	@echo; echo "== Argo CD apps (want: Synced / Healthy) =="; kubectl -n argocd get applications -o custom-columns=APP:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status
	@echo; echo "== Pods that are NOT healthy (empty = good) =="; kubectl get pods -A --no-headers | awk '$$4!="Running" && $$4!="Completed"' || true
	@echo; echo "== Hospitals =="; kubectl get pods -n hospital-a; kubectl get pods -n hospital-b
	@echo; echo "== Web addresses =="; kubectl get ingress -A

stop:
	for n in $$(terraform -chdir=terraform output -json node_names | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)))"); do $(VIRSH) shutdown $$n; done

start:
	for n in $$(terraform -chdir=terraform output -json node_names | python3 -c "import sys,json; print(' '.join(json.load(sys.stdin)))"); do $(VIRSH) start $$n; done
	@echo "Wait about 2 minutes, then run: make vault   (Vault is sealed after a restart)"

destroy:
	terraform -chdir=terraform destroy -auto-approve
	rm -f kubeconfig .rke2-token .vault-init.json .vault-secrets.txt

minio-down:
	cd minio && docker compose down

down: destroy minio-down
	@echo "VMs deleted and MinIO stopped. RAM is free. Disk: run  make wipe  to free that too."

wipe: destroy
	cd minio && docker compose down -v
	rm -rf terraform/.terraform terraform/terraform.tfstate* ansible/inventory.ini
	-$(VIRSH) pool-destroy hospital
	-$(VIRSH) pool-undefine hospital
	-$(VIRSH) net-destroy hospital
	-$(VIRSH) net-undefine hospital
	rm -rf /var/lib/libvirt/images/hospital 2>/dev/null || sudo rm -rf /var/lib/libvirt/images/hospital
	@echo "Everything of this project is removed. Check with: virsh -c qemu:///system list --all ; docker ps -a"