terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5.1"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.2"
    }
  }
  required_version = ">= 1.0.0, >= 1.9.0"
}
provider "azurerm" {
  features {}
}
