variable "secure_mesh_site_provider" {}
variable "ssh_public_key" {}
variable "f5xc_cluster_name" {}

variable "master_node_count" {
  type = number
  default = 0
}
variable "worker_node_count" {
  type = number
  default = 0
}
variable "secure_mesh_node_count" {
  type = number
  default = 0
}
variable "master_cpus" {
  type = number
  default = 4
}
variable "master_memory" {
  type = number
  default = 16384
}
variable "worker_cpus" {
  type = number
  default = 4
}
variable "worker_memory" {
  type = number
  default = 16384
}
variable "http_proxy" {
  type = string
  default = ""
}
variable "f5xc_api_url" {
  type = string
}
variable "f5xc_api_token" {
  type = string
}
variable "f5xc_tenant" {
  type = string
}
variable "secure_mesh_cpus" {
  type = number
  default = 4
}
variable "secure_mesh_memory" {
  type = number
  default = 16384
}
variable "f5xc_registration_wait_time" {
    type    = number
    default = 60
}

variable "f5xc_registration_retry" {
    type    = number
    default = 20
}

variable "f5xc_tunnel_type" {
  type    = string
  default = "SITE_TO_SITE_TUNNEL_IPSEC_OR_SSL"
}

variable "operating_system_version" {
  type    = string
  default = ""
}

variable "volterra_software_version" {
  type    = string
  default = ""
}

variable "outside_macaddr" {
  type    = string
  default = ""
}

variable "inside_vip" {
  type  = string
  default = ""
}

variable "master_vm_size" {
  type = string
  default = "80G"
}

variable "worker_vm_size" {
  type = string
  default = "80G"
}

variable "slo_global_vn" {
  type = string
  default = ""
}

# AWS

variable "aws_vpc_cidr" {
  type = string
  default = ""
}
variable "aws_owner_tag" {
  type = string
  default = ""
}
variable "aws_subnet_slo" {
  type = list(string)
}
variable "aws_subnet_sli" {
  type = list(string)
}
variable "aws_sg_allow_slo_traffic" {
  type = string
}
variable "aws_sg_allow_sli_traffic" {
  type = string
}
variable "aws_availability_zones" {
  type = list(string)
  default = []
}
variable "aws_instance_type" {
  type = string
  default = ""
}
variable "aws_ami_id" {}
