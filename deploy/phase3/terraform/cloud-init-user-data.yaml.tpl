#cloud-config
# First-boot setup of each VM: hostname, an 'ops' user with your SSH key, no password login.
hostname: ${hostname}
manage_etc_hosts: true
users:
  - name: ops
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${ssh_key}
ssh_pwauth: false
