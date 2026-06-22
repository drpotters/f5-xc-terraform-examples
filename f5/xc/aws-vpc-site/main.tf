locals {
  project_prefix      = var.prefix
  vpc_name            = "${var.prefix}-${random_id.rand_id.hex}-vpc"
  internet_gw_name    = "${var.prefix}-${random_id.rand_id.hex}-igw"
  igw_route_name      = "${var.prefix}-${random_id.rand_id.hex}-rt2"
  security_grp_name_1 = "${var.prefix}-${random_id.rand_id.hex}-sgrp-1"
  security_grp_name_2 = "${var.prefix}-${random_id.rand_id.hex}-sgrp-2"
}

resource "random_id" "rand_id" {
  byte_length = 3
}

data "aws_ami" "smsv2" {
  owners      = ["434481986642"]
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_name]
  }
}


resource "aws_instance" "sm_ec2_instances" {
  count         = var.ec2_instances_count
  ami           = data.aws_ami.smsv2.id
  instance_type = var.instance_type

  root_block_device {
    volume_size = var.ec2_disk_size
  }

  network_interface {
    network_interface_id = element(aws_network_interface.sm_public_eni[*].id, count.index)
    device_index         = 0
  }
  network_interface {
    network_interface_id = element(aws_network_interface.sm_private_eni[*].id, count.index)
    device_index         = 1
  }

  user_data = templatefile("${path.module}/templates/cloud-config-base.tmpl", {
    cluster_token = var.cluster_token
  })

  tags = {
    Name = "${local.project_prefix}-${random_id.rand_id.hex}-${count.index}"
  }
}