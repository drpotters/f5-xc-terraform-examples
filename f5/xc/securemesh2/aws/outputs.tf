output "sm_instance_ids" {
  value = aws_instance.sm_ec2_instances[*].id
}

output "sm_instance_public_ips" {
  value = aws_eip.sm_pub_ips[*].public_ip
}

output "sm_instance_names" {
  value = aws_instance.sm_ec2_instances[*].tags["Name"]
}

output "sm_vpc_name" {
  value = aws_vpc.sm_vpc.tags["Name"]
}

output "client_vm_ip" {
  value = length(module.client) > 0 ? module.client[0].client_vm_ip : []
}

output "server_vm_ip" {
  value = length(module.server) > 0 ? module.server[0].server_vm_ip : []
}