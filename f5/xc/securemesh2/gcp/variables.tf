variable "project_id" {
  description = "The ID of the project in which to provision resources."
  type        = string
}

// Marketplace requires this variable name to be declared
variable "goog_cm_deployment_name" {
  description = "The name of the deployment and VM instance."
  type        = string
}

variable "source_image_path" {
  description = "The image path for the disk for the VM instance."
  type        = string
  default     = "projects/mpi-f5-7626-networks-public/global/images"
}

variable "source_image_name" {
  description = "The image version"
  type = string
  default = ""
}

variable "zones" {
  description = "The zone for the solution to be deployed."
  type        = list
  default     = ["us-east1-b","us-east1-c","us-east1-d"]
}

variable "instance_count" {
  description = "number of instances to be spawned"
  type = number
  default = 3
}

variable "machine_type" {
  description = "The machine type to create, e.g. e2-small"
  type        = string
  default     = "t2d-standard-8"
}

variable "boot_disk_size" {
  description = "The boot disk size for the VM instance in GBs"
  type        = number
  default     = 80
}

variable "networks" {
  description = "The network name to attach the VM instance."
  type        = list(string)
  default     = ["securemeshv2-automation-slo", "securemeshv2-automation-sli", "securemeshv2-automation-sli-2"]
}

variable "sub_networks" {
  description = "The sub network name to attach the VM instance."
  type        = list(string)
  default     = ["smv2-slo", "smv2-sli", "smv2-sli-2"]
}

variable "external_ips" {
  description = "The external IPs assigned to the VM for public access."
  type        = list(string)
  default     = ["EPHEMERAL"]
}

variable "subnets" {
  description = "List of subnets from different VPCs"
  type        = list(object({
    name    = string
    network = string
  }))
  default = [
    { name = "smv2-slo", network = "securemeshv2-automation-slo" },
    { name = "smv2-sli", network = "securemeshv2-automation-sli" },
    { name = "smv2-sli-2", network = "securemeshv2-automation-sli-2" }
  ]
}

variable "ssh_keys" {
  type        = list(string)
  description = "The SSH public key to access the site admin CLI."
  default     = []
}

variable "token" {
  description = "The token created in F5 Console."
  type        = string
  default     = ""
}

variable "network_tags" {
  type        = list(string)
  default     = ["smv2"]
  description = "Use the one created for the egress network firewall rule."
}