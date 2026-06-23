output "instance_info" {
  description = "List of instance names with public IPs"
  value = {
    for i, instance in oci_core_instance.smv2_instances :
    instance.display_name => instance.public_ip
  }
}