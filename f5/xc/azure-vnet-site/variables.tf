variable "node_prefix" {
  type    = string
  default = "az-ce-node"
}

variable "cluster_token" {
  type    = string
  default = ""
}

variable "az_location" {
  type    = string
  default = "eastus"
}

variable "az_rg_name" {
  type    = string
  default = ""
}

variable "az_virtual_network" {
  type    = string
  default = ""
}

variable "az_vnet_resource_group_name" {
  type    = string
  default = ""
}

variable "az_public_subnet_name" {
  type    = string
  default = ""
}

variable "az_private_subnet_name" {
  type    = string
  default = ""
}

variable "az_nsg_name" {
  type        = string
  description = "Name of an existing Network Security Group to associate with the SLO NIC. Leave empty to skip NSG association."
  default     = ""
}

variable "instances" {
  type    = number
  default = 1
}

variable "sku_flavor" {
  type    = string
  default = "Standard_D8_v4"
}

variable "disk_size" {
  type    = number
  default = 80
}

variable "image_version" {
  type    = string
  default = "latest"
}

variable "image_publisher" {
  type    = string
  default = "f5-networks"
}

variable "image_offer" {
  type    = string
  default = "f5xc_customer_edge"
}

variable "image_sku" {
  type    = string
  default = "f5-distributed-cloud-ce-crt"
}
