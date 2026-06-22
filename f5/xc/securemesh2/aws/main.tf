locals {
    project_prefix    = var.prefix
    vpc_name          = "${var.prefix}-${random_id.rand_id.hex}-vpc"
    internet_gw_name  = "${var.prefix}-${random_id.rand_id.hex}-igw"
    igw_route_name    = "${var.prefix}-${random_id.rand_id.hex}-rt2"
    security_grp_name_1 = "${var.prefix}-${random_id.rand_id.hex}-sgrp-1"
    security_grp_name_2 = "${var.prefix}-${random_id.rand_id.hex}-sgrp-2"
}

resource "random_id" "rand_id" {
  byte_length = 3
}

data "aws_ami" "smsv2" {
  owners = ["434481986642"]
  most_recent = true

  filter {
    name   = "name"
    values = [ var.ami_name ]
  }
}

data "template_file" "vpm_config_data" {
  count         = var.ec2_instances_count
  template      = "${file("${path.module}/templates/cloud-config-base.tmpl")}"
  vars          = {
      cluster_token = "${var.cluster_token}"
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

  user_data = data.template_file.vpm_config_data[count.index].rendered

  tags = {
    Name = "${local.project_prefix}-${random_id.rand_id.hex}-${count.index}"
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
}

module "client" {
  source = "./client"
  count = var.client_ec2_instances_count > 0 ? 1 : 0

  random_id = random_id.rand_id.hex 
  client_ec2_instances_count = var.client_ec2_instances_count
  project_prefix = local.project_prefix
  user_email = var.user_email
  env = var.env
  user_costcenter = var.user_costcenter
  user_manager = var.user_manager
  user_team = var.user_team

  public_subnet_ids  = aws_subnet.sm_public_subnet[*].id 
  private_subnet_ids = aws_subnet.sm_private_subnet[*].id
  security_group_id_1  = aws_security_group.sm_sg_part_1.id
  security_group_id_2  = aws_security_group.sm_sg_part_2.id
}

module "server" {
  source = "./server"
  count = var.server_ec2_instances_count > 0 ? 1 : 0

  random_id = random_id.rand_id.hex 
  server_ec2_instances_count = var.server_ec2_instances_count
  project_prefix = local.project_prefix
  user_email = var.user_email
  env = var.env
  user_costcenter = var.user_costcenter
  user_manager = var.user_manager
  user_team = var.user_team

  public_subnet_ids  = aws_subnet.sm_public_subnet[*].id
  private_subnet_ids = aws_subnet.sm_private_subnet[*].id
  security_group_id_1  = aws_security_group.sm_sg_part_1.id
  security_group_id_2  = aws_security_group.sm_sg_part_2.id
}