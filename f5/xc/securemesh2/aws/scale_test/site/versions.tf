terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.56.1"
    }    
    restapi = {
      source = "Mastercard/restapi"
      version = "1.19.1"
    }
  }
}
