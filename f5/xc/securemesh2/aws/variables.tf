variable "region" {
  type = string
  default = "us-east-1"
}
variable "prefix" {
  type = string
  default = "test-sm2"
}

variable "public_subnet_cidrs" {
 type        = list(string)
 default     = ["10.0.40.0/24", "10.0.50.0/24", "10.0.60.0/24"]
}
 
variable "private_subnet_cidrs" {
 type        = list(string)
 default     = ["10.0.70.0/24", "10.0.80.0/24", "10.0.90.0/24"]
}

variable "ec2_azs" {
 type        = list(string)
 description = "EC2 Availability Zones"
 default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "ec2_instances_count" {
    type = number
    default = 3
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

variable "client_ec2_instances_count" {
  type = number
  default = 0
}

variable "server_ec2_instances_count" {
  type = number
  default = 0
}

variable "f5_allowed_cidrs" {
  description = "BIG IP VPN allowed CIDR blocks for access"
  type        = list(string)

  default = [
    "0.0.0.0/0",
    "106.38.20.192/28",
    "125.35.28.80/28",
    "50.236.107.0/28",
    "162.220.44.16/28",
    "111.223.104.64/27",
    "42.61.112.48/28",
    "65.61.116.96/28",
    "203.47.24.240/28",
    "189.201.174.96/28",
    "62.90.170.80/28",
    "84.108.132.208/28",
    "210.226.41.192/27",
    "113.43.213.160/27",
    "201.168.196.176/28",
    "1.6.70.48/28",
    "115.110.154.64/28",
    "104.219.104.11/32",
    "104.219.105.11/32",
    "104.219.106.11/32",
    "104.219.107.11/32",
    "104.219.108.11/32",
    "104.219.109.11/32",
    "3.140.195.80/32",
    "3.148.178.191/32",
    "18.119.142.194/32",
    "16.59.137.233/32",
    "18.188.143.199/32",
    "18.218.178.229/32",
    "3.131.151.184/32",
    "18.218.42.38/32"
  ]
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