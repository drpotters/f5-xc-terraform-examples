terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.53.0"
    }
    random = {
      source = "hashicorp/random"
      version = "~>3.6.0"
    }
  }
  required_version = ">= 1.0.0, >= 1.9.0"
}

provider "openstack" {
    cloud = var.cloud_name
}
