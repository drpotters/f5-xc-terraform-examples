
locals {
    project_prefix    = var.prefix
}

provider "aws" {
  region  = var.region
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
  count         = var.ec2_workers_count
  template      = "${file("${path.module}/templates/cloud-config-base.tmpl")}"
  vars          = {
      cluster_token = "${var.cluster_token}"
  }
}

data "aws_security_group" "sm_sg" {
  id = var.sm_security_group
}

resource "aws_network_interface" "slo_intferace" {
  count         = var.ec2_workers_count
  subnet_id     = var.slo_subnet_id
  security_groups = [data.aws_security_group.sm_sg.id]

  tags = {
    Name = "${var.prefix}-${var.randomid}-slo-eni${count.index + 1}"
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
}

resource "aws_network_interface" "sli_intferace" {
  count         = var.ec2_workers_count
  subnet_id     = var.sli_subnet_id
  security_groups = [data.aws_security_group.sm_sg.id]

  tags = {
    Name = "${var.prefix}-${var.randomid}-sli-eni${count.index + 1}"
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
}


resource "aws_instance" "sm2_worker_instances" {
  count         = var.ec2_workers_count
  ami           = data.aws_ami.smsv2.id
  instance_type = var.instance_type

  root_block_device {
    volume_size = var.ec2_disk_size
  }

  network_interface {
    network_interface_id = aws_network_interface.slo_intferace[count.index].id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.sli_intferace[count.index].id
    device_index         = 1
  }

  user_data = data.template_file.vpm_config_data[count.index].rendered

  tags = {
    Name = "${local.project_prefix}-${var.randomid}-worker-${count.index}"
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
}

resource "aws_eip" "sm_worker_pub_ips" {
  count             = var.ec2_workers_count
}

resource "aws_eip_association" "sm_worker_eips" {
  count                = var.ec2_workers_count
  network_interface_id = aws_network_interface.slo_intferace[count.index].id
  allocation_id        = aws_eip.sm_worker_pub_ips[count.index].id

  depends_on = [aws_instance.sm2_worker_instances]
}