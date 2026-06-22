locals {
  name_prefix  =  "${var.node_prefix}-${random_string.rand_name.result}"
}

resource "random_string" "rand_name" {
  length   = 4
  lower    = true
  upper    = false
  special  = false
  numeric  = false
}

data "template_file" "vpm_config_data" {
  count         = var.cluster_count
  template      = "${file("${path.module}/templates/cloud-config-base.tmpl")}"
  vars          = {
      cluster_token = "${var.cluster_token}"
      node_name     = "${local.name_prefix}-${count.index + 1}"
  }
}

# Create an instance
resource "openstack_compute_instance_v2" "instance" {
  count           = var.cluster_count
  name            = "${local.name_prefix}-${count.index + 1}"
  image_name      = var.image_name
  flavor_name     = var.instance_flavor
  user_data       = data.template_file.vpm_config_data[count.index].rendered
  security_groups = var.security_groups

  dynamic "network" {
    for_each = var.networks_list
    content {
      name = network.value
    }
  }

}