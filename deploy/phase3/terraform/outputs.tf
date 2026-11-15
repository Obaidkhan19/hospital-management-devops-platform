# outputs.tf - what Terraform prints after apply (the Makefile uses node_names to stop and start the VMs).

output "node_names" {
  value = keys(local.nodes)
}

output "server_ips" {
  value = { for k, v in local.servers : k => v.ip }
}

output "worker_ips" {
  value = { for k, v in local.workers : k => v.ip }
}
