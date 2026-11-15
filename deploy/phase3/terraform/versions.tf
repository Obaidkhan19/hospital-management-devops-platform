# versions.tf - pins Terraform and its two providers.
#   libvirt = talks to KVM on your laptop and creates the VMs.
#   local   = writes the Ansible inventory file from the VM list.
terraform {
  required_version = ">= 1.6"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.8.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}
