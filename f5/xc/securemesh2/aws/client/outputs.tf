output "client_vm_ip" {
  value = aws_eip.sm_client_pub_ips[*].public_ip
}