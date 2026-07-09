variable "server_ec2_instances_count" {
    type = number
}

variable "server_instance_type" {
  type = string
  default = "t3.medium"
}

variable "ubuntu_ami_name_pattern" {
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "server_ec2_disk_size" {
  type = number
  default = 20
}

variable "user_email" {
  type = string
}

variable "user_costcenter" {
  type = string
}

variable "env" {
  type = string
}

variable "user_manager" {
  type = string
}

variable "user_team" {
  type = string
}

variable "project_prefix" {
  type = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "security_group_id_1" {
  description = "Security group ID 1"
  type        = string
}

variable "security_group_id_2" {
  description = "Security group ID 2"
  type        = string
}

variable "random_id" {
  description = "Random ID for resource naming"
  type        = string
}