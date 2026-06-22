# Variables

variable "networks_list" {
  type  = list
  default = ["Adminnetwork", "f5-xc-sli"] # Adding both SLO and SLI by default
}

variable "security_groups" {
  type    = list(string)
  default = ["default"]  # Name of default security group
}

variable "cluster_count" {
  description = "Number of instances to create"
  default = "1"
}

variable "node_prefix" {
  type        = string
  default     = "auto-os"
}

variable "cluster_token" {
  type  = string
  default = ""
}

variable "instance_flavor" {
  type = string
  default = "m1.xc_smsv2_medium"
}

variable "image_name" {
  type = string
  default = ""
}

variable "cloud_name" {
  description = "Name of the OpenStack cloud config to use - hyd or sjc"
  type        = string
}