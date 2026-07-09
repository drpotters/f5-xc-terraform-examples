output "sm_worker_ids" {
  value = aws_instance.sm2_worker_instances[*].id
}

output "sm_instance_public_ips" {
  value = aws_eip.sm_worker_pub_ips[*].public_ip
}

output "sm_instance_names" {
  value = aws_instance.sm2_worker_instances[*].tags["Name"]
}