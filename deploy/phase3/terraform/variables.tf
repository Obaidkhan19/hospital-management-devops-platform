# variables.tf - every setting you may want to change. Defaults fit a 32 GB laptop.

variable "libvirt_uri" {
  description = "KVM connection. qemu:///system is the normal local one."
  type        = string
  default     = "qemu:///system"
}

variable "ssh_public_key_path" {
  description = "Public key copied into the VMs for the user 'ops'. Create one with: ssh-keygen -t ed25519"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "server_count" {
  description = "Control-plane nodes. 1 for the laptop. 3 later for HA. Never 2 (etcd needs a majority)."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3], var.server_count)
    error_message = "server_count must be 1 or 3. Two control-plane nodes are worse than one."
  }
}

variable "worker_count" {
  description = "Worker nodes that run the hospital pods and the platform tools."
  type        = number
  default     = 2
}

variable "server_memory_mb" {
  type    = number
  default = 8192
}

variable "server_vcpus" {
  type    = number
  default = 2
}

variable "worker_memory_mb" {
  description = "8 GB each, because Rancher, monitoring and two SQL Servers run here."
  type        = number
  default     = 6144
}

variable "worker_vcpus" {
  type    = number
  default = 3
}

variable "disk_gb" {
  type    = number
  default = 40
}

variable "network_prefix" {
  description = "VM network is <prefix>.0/24. MetalLB uses .200-.220 (set in gitops/config/metallb). Change in both places if it clashes with your LAN."
  type        = string
  default     = "10.10.10"
}

variable "pool_path" {
  description = "Folder for the VM disks."
  type        = string
  default     = "/var/lib/libvirt/images/hospital"
}

variable "base_image_url" {
  description = "Ubuntu cloud image used for every VM."
  type        = string
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}
