output "server_vm_ip" {
  value = aws_eip.sm_server_pub_ips[*].public_ip
}