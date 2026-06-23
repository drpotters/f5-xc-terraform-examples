resource "random_id" "rand_id" {
  byte_length = 3
}

data "oci_core_virtual_networks" "vcn_list" {
  compartment_id = var.compartment_id
}

# Fetch vcn id by the vcn name 
locals {
  vcn_id = [for vcn in data.oci_core_virtual_networks.vcn_list.virtual_networks : vcn.id if vcn.display_name == var.vcn_name]
}

# Fetch existing subnets dynamically
data "oci_core_subnets" "vcn_existing_subnets" {
  compartment_id = var.compartment_id
  vcn_id         = length(local.vcn_id) > 0 ? local.vcn_id[0] : null
}

locals {
  subnet_id_map = { for s in data.oci_core_subnets.vcn_existing_subnets.subnets : s.display_name => s.id }

  slo_subnet_ids = [for name in var.slo_subnet_names : lookup(local.subnet_id_map, name, null)]
  sli_subnet_ids = [for name in var.sli_subnet_names : lookup(local.subnet_id_map, name, null)]
}

# Fetch f5xc ce custom image
data "oci_core_images" "smv2_custom_image" {
  compartment_id = var.compartment_id
  display_name   = var.f5xc_image_display_name
}

data "oci_identity_availability_domains" "avdomains" {
  compartment_id = var.compartment_id
}

data "template_file" "vpm_config_data" {
  count         = var.instance_count
  template      = "${file("${path.module}/templates/cloud-config-base.tmpl")}"
  vars          = {
      node_token = "${var.node_token}"
  }
}

resource "oci_core_instance" "smv2_instances" {
  count                 = var.instance_count
  display_name          = "${var.project_prefix}-${random_id.rand_id.hex}-${count.index + 1}"
  availability_domain   = data.oci_identity_availability_domains.avdomains.availability_domains[count.index].name 
  compartment_id        = var.compartment_id
  shape                 = var.shape

  shape_config {
    ocpus         = 4
    memory_in_gbs = 32
  }

  # Primary SLO interface configuration
  create_vnic_details {
    subnet_id        = local.slo_subnet_ids[count.index]
    assign_public_ip = true
    display_name = "nic-slo-${random_id.rand_id.hex}-${count.index + 1}"
  }

  timeouts {
    create = "60m"
    delete = "60m"
  }

  # attaching the f5xc custom image to the VM
  source_details {
    source_type           = "image"
    source_id             = data.oci_core_images.smv2_custom_image.images[0].id
    boot_volume_size_in_gbs = var.boot_disk_size
  }

  # replace the cloud-init file with custom cloud init script with required parameters
  metadata = {
      user_data = base64encode(data.template_file.vpm_config_data[count.index].rendered)
  }

}

# Attaching a secondary SLI interface to each VM
resource "oci_core_vnic_attachment" "secondary_vnic" {
  count              = var.instance_count
  instance_id        = oci_core_instance.smv2_instances[count.index].id
  create_vnic_details {
    subnet_id        = local.sli_subnet_ids[count.index]
    assign_public_ip = false
    display_name = "nic-sli-${random_id.rand_id.hex}-${count.index + 1}"
  }
  timeouts {
    create = "60m"
    delete = "60m"
  }
}