# main.tf - creates the VMs for the RKE2 cluster on your laptop (KVM).
#   1 private network  ->  1 base disk  ->  1 disk + cloud-init + VM per node.
# Servers get .11, .12, .13 and workers .21, .22 ... Terraform also writes ../ansible/inventory.ini.
#KVM = 3 Kernel-based Virtual Machine  (2 worker and 1 control)

#libvirt is a virtualization management system.

provider "libvirt" {
  uri = var.libvirt_uri
}

locals {
  ssh_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
  gateway = "${var.network_prefix}.1"

  servers = {
    for i in range(var.server_count) : "rke2-server-${i + 1}" => {
      ip     = "${var.network_prefix}.${11 + i}"
      mac    = format("52:54:00:10:10:%02x", 11 + i)
      memory = var.server_memory_mb
      vcpu   = var.server_vcpus
    }
  }

  workers = {
    for i in range(var.worker_count) : "rke2-worker-${i + 1}" => {
      ip     = "${var.network_prefix}.${21 + i}"
      mac    = format("52:54:00:10:10:%02x", 21 + i)
      memory = var.worker_memory_mb
      vcpu   = var.worker_vcpus
    }
  }

  nodes = merge(local.servers, local.workers)
}

resource "libvirt_pool" "hospital" {
  name = "hospital"
  type = "dir"
  path = var.pool_path
}

# NAT network: VMs reach the internet, your laptop (10.10.10.1) reaches the VMs.
resource "libvirt_network" "hospital" {
  name      = "hospital"
  mode      = "nat"
  domain    = "hospital.test"
  addresses = ["${var.network_prefix}.0/24"]

  dhcp {
    enabled = false # static IPs come from cloud-init
  }

  dns {
    enabled = true
  }
}

resource "libvirt_volume" "base" {
  name   = "ubuntu-noble-base.qcow2"
  pool   = libvirt_pool.hospital.name
  source = var.base_image_url
  format = "qcow2"
}

resource "libvirt_volume" "node" {
  for_each       = local.nodes
  name           = "${each.key}.qcow2"
  pool           = libvirt_pool.hospital.name
  base_volume_id = libvirt_volume.base.id
  size           = var.disk_gb * 1024 * 1024 * 1024
}

resource "libvirt_cloudinit_disk" "node" {
  for_each = local.nodes
  name     = "${each.key}-init.iso"
  pool     = libvirt_pool.hospital.name

  user_data = templatefile("${path.module}/cloud-init-user-data.yaml.tpl", {
    hostname = each.key
    ssh_key  = local.ssh_key
  })

  network_config = templatefile("${path.module}/cloud-init-network.yaml.tpl", {
    mac     = each.value.mac
    ip      = each.value.ip
    gateway = local.gateway
  })
}

resource "libvirt_domain" "node" {
  for_each  = local.nodes
  name      = each.key
  memory    = each.value.memory
  vcpu      = each.value.vcpu
  cloudinit = libvirt_cloudinit_disk.node[each.key].id
  autostart = false

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_id = libvirt_network.hospital.id
    mac        = each.value.mac
  }

  disk {
    volume_id = libvirt_volume.node[each.key].id
  }
}

resource "local_file" "inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/inventory.tpl", {
    servers = local.servers
    workers = local.workers
  })
}
