variable "project_prefix" {
  type        = string
  default     = "f5xc"
}

variable "ssh_public_key" {
  type        = string
  default     = ""
}

# F5XC 

variable "f5xc_api_url"        {}
variable "f5xc_api_token"      {}
variable "f5xc_tenant"         {}

# AWS

variable "aws_access_key" {
  type = string
  default = ""
}
variable "aws_secret_key" {
  type = string
  default = ""
}
variable "aws_owner_tag" {
  type = string
  default = ""
}
variable "aws_region" {
  type = string
  default = ""
}
variable "aws_availability_zones" {
  type = list(string)
  default = []
}
variable "aws_ami_name" {
  type = string
}
variable "aws_site_count" {
  type = number
  default = 0
}
variable "aws_slo_subnets" {
  type = list(string)
}
variable "aws_sli_subnets" {
  type = list(string)
  default = []
}
variable "aws_vpc_cidr" {
  type = string
}
variable "master_node_count" {
  type = number
  default = 1
}
variable "worker_node_count" {
  type = number
  default = 0
}
