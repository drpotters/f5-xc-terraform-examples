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
