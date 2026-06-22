output "sm_azure_vm_ips" {
  value = azurerm_public_ip.smv2_slo_public_ip[*].ip_address
}

output "slo_nic_names" {
  value = azurerm_network_interface.slo_nic[*].name
}

output "slo_nic_private_ips" {
  value = azurerm_network_interface.slo_nic[*].private_ip_address
}

output "sli_nic_names" {
  value = azurerm_network_interface.sli_nic[*].name
}

output "sli_nic_private_ips" {
  value = azurerm_network_interface.sli_nic[*].private_ip_address
}

output "vm_names" {
  value = azurerm_linux_virtual_machine.smv2_instance[*].name
}
