output "sm_azure_vm_ips" {
  value = azurerm_public_ip.smv2_slo_public_ip[*].ip_address
}