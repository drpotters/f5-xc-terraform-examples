locals {
  name_prefix = "${var.node_prefix}-${random_string.rand_name.result}"
}

resource "random_string" "rand_name" {
  length  = 4
  lower   = true
  upper   = false
  special = false
  numeric = false
}

resource "tls_private_key" "adminuserkey" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


data "azurerm_resource_group" "main" {
  name = var.az_rg_name
}

data "azurerm_virtual_network" "sm2_vnet" {
  name                = var.az_virtual_network
  resource_group_name = var.az_rg_name
}

data "azurerm_subnet" "public" {
  name                 = var.az_public_subnet_name
  virtual_network_name = data.azurerm_virtual_network.sm2_vnet.name
  resource_group_name  = var.az_rg_name
}

data "azurerm_subnet" "private" {
  name                 = var.az_private_subnet_name
  virtual_network_name = data.azurerm_virtual_network.sm2_vnet.name
  resource_group_name  = var.az_rg_name
}

data "azurerm_network_security_group" "sm2_nsg" {
  count               = var.az_nsg_name != "" ? 1 : 0
  name                = var.az_nsg_name
  resource_group_name = var.az_rg_name
}

resource "azurerm_public_ip" "smv2_slo_public_ip" {
  count               = var.instances
  name                = "${local.name_prefix}-pub-ip-${random_string.rand_name.result}-${count.index + 1}"
  location            = var.az_location
  resource_group_name = var.az_rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "slo_nic" {
  count               = var.instances
  name                = "${local.name_prefix}-slo-nic-${random_string.rand_name.result}-${count.index + 1}"
  location            = var.az_location
  resource_group_name = var.az_rg_name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.public.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.smv2_slo_public_ip[count.index].id
  }
}

resource "azurerm_network_interface_security_group_association" "slo_nic_nsg_assoc" {
  count                     = var.az_nsg_name != "" ? var.instances : 0
  network_interface_id      = azurerm_network_interface.slo_nic[count.index].id
  network_security_group_id = data.azurerm_network_security_group.sm2_nsg[0].id
}

resource "azurerm_network_interface" "sli_nic" {
  count               = var.instances
  name                = "${local.name_prefix}-sli-nic-${random_string.rand_name.result}-${count.index + 1}"
  location            = var.az_location
  resource_group_name = var.az_rg_name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.private.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "smv2_instance" {
  count               = var.instances
  name                = "${local.name_prefix}-${count.index + 1}"
  resource_group_name = var.az_rg_name
  location            = var.az_location
  size                = var.sku_flavor
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.slo_nic[count.index].id,
    azurerm_network_interface.sli_nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = var.disk_size
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  plan {
    name      = var.image_sku
    product   = var.image_offer
    publisher = var.image_publisher
  }

  custom_data = base64encode(templatefile("${path.module}/templates/cloud-config-base.tmpl", {
    cluster_token = var.cluster_token
  }))

  admin_ssh_key {
    username   = "adminuser"
    public_key = tls_private_key.adminuserkey.public_key_openssh
  }
}