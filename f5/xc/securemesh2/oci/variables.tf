variable "project_prefix" {
  type = string
  default = "qa-oci"
}

variable "region" {
  type = string
  default = "us-phoenix-1"
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
  default     = "ocid1.compartment.oc1..aaaaaaaasg3gcrrxqv2o7au7otkzxtzcggs7zlycf5zr7al6siq7qxizwirq"
}

variable "vcn_name" {
  description = "OCI VCN NAME"
  type        = string
  default     = "vcn-for-smsv2-testing"
}

variable "slo_subnet_names" {
  description = "List of slo subnet names, one per AD"
  type        = list(string)
  default = [ "subnet-slo-ad1", "subnet-slo-ad2", "subnet-slo-ad3" ]
}

variable "sli_subnet_names" {
  description = "List of slo subnet names, one per AD"
  type        = list(string)
  default = [ "subnet-sli-ad1", "subnet-sli-ad2", "subnet-sli-ad3" ]
}

variable "bucket_name" {
  description = "OCI Object Storage Bucket Name"
  type        = string
  default     = "f5xc-smv2-images"
}

variable "shape" {
  description = "Compute instance shape"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

variable "instance_count" {
  description = "Number of instances (1 or 3)"
  type        = number
  default     = 1
}

variable "availability_domains" {
  description = "List of ADs in the region"
  type        = list(string)
  default = ["AD-1", "AD-2", "AD-3"]
}

variable "f5xc_image_display_name" {
    type = string
}

variable "boot_disk_size" {
  type = number
  default = 80
}

variable "node_token" {
  type = string
}