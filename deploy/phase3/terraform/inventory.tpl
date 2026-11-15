# Written by Terraform (inventory.tpl). Do not edit, it is overwritten on every apply.
[rke2_servers]
%{ for name, n in servers ~}
${name} ansible_host=${n.ip}
%{ endfor ~}

[rke2_agents]
%{ for name, n in workers ~}
${name} ansible_host=${n.ip}
%{ endfor ~}

[all:vars]
ansible_user=ops
ansible_python_interpreter=/usr/bin/python3
