variable "node_prefix" {
  type = string
  default = "az-sm2-node"
}

variable "cluster_token" {
  type = string
  default = ""
}

variable "az_location" {
  type = string
  default = "eastus"
}

variable "az_rg_name" {
  type = string
  default = "securemeshv2-testing"
}

variable "az_virtual_network" {
    type = string
    default = "sm2-test-network"
}

variable "az_vnet_resource_group_name" {
  type = string
  default = "securemeshv2-testing"
}

variable "az_public_subnet_name" {
  type = string
  default = "slo-default"
}

variable "az_private_subnet_name" {
  type = string
  default = "sli-default"
}

variable "instances" {
  type = number
  default = 1
}

variable "sku_flavor" {
  type = string
  default = "Standard_D8_v4"
}

variable "disk_size" {
  default = 80
}

variable "sm2_subscription" {
  type = string
  default = "f68d94a5-1db7-4954-9a79-02b5711cb0a1"
}

variable "image_version" {
  type = string
  default = ""
}

variable "image_publisher" {
  type = string
  default = "f5-networks"
}

variable "image_offer" {
  type = string
  default = "f5xc_customer_edge"
}

variable "image_sku" {
  type = string
  default = "f5-distributed-cloud-ce-crt"
}

/*variable "f5xc_image_name" {
  type = string
  default = "F5XC_CE"
}

variable "f5xc_official_gallery" {
  type = string
  default = "F5XC_Images"
}

variable "f5xc_image_version" {
  type = string
  default = "latest"
}

variable "f5xc_gallery_rgroup" {
  type = string
  default = "SECUREMESHV2-PROD-IMAGES"
}*/