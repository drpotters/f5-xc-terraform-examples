variable "region" {
  type    = string
  default = "us-east-1"
}

variable "prefix" {
  type    = string
  default = "f5xc-ce"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.40.0/24", "10.0.50.0/24", "10.0.60.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.70.0/24", "10.0.80.0/24", "10.0.90.0/24"]
}

variable "ec2_azs" {
  type        = list(string)
  description = "EC2 Availability Zones"
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "ec2_instances_count" {
  type    = number
  default = 1
}

variable "instance_type" {
  type    = string
  default = "m5.2xlarge"
}

variable "ami_name" {
  type    = string
  default = ""
}

variable "ec2_disk_size" {
  type    = number
  default = 80
}

variable "cluster_token" {
  type    = string
  default = ""
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed for inbound access on the SLO security group"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "re_ce_allowed_cidrs" {
  description = "CIDR blocks allowed for RE and CE communication"
  type        = list(string)
  default = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16"
  ]
}
