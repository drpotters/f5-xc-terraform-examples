variable "prefix" {
  type = string
}

variable "region" {
  type = string
}

variable "slo_subnet_id" {
 type        = string
}
 
variable "sli_subnet_id" {
 type        = string
}

variable "ec2_workers_count" {
    type = number
}

variable "sm_security_group" {
    type = string
}

variable "instance_type" {
  type = string
  default = "m5.2xlarge"
}

variable "ami_name" {
    type = string
    default = ""
}

variable "ec2_disk_size" {
  type = number
  default = 80
}

variable "cluster_token" {
  type = string
  default = ""
}

variable "randomid" {
  type = string
}

variable "env" {
  type = string
}

variable "user_email" {
  type = string
}

variable "user_costcenter" {
  type = string
}

variable "user_manager" {
  type = string
}

variable "user_team" {
  type = string
}