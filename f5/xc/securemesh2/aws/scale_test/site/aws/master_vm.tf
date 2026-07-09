resource "aws_instance" "master_vm" {
  count         = var.master_node_count
  ami           = var.aws_ami_id
  instance_type = var.aws_instance_type

  root_block_device {
    volume_size = var.ec2_disk_size
  }

  network_interface {
    network_interface_id = element(aws_network_interface.sm_slo_eni[*].id, count.index)
    device_index         = 0
  }
  dynamic "network_interface" {
    for_each = range(0, length(var.aws_subnet_sli))
    content {
      network_interface_id = element(aws_network_interface.sm_sli_eni[*].id, count.index)
      device_index         = 1
    }
  }

  user_data = templatefile("${path.module}/templates/cloud-config-base.tmpl", {
      node_registration_token = var.f5xc_registration_token
  })

  tags = {
    Name = format("%s-m%d", var.f5xc_cluster_name, count.index)
    ves-io-site-name = var.f5xc_cluster_name
    "kubernetes.io/cluster/${var.f5xc_cluster_name}" = "owned"
    Creator = var.aws_owner_tag
  }
}

resource "aws_network_interface" "sm_slo_eni" {
  count           = var.master_node_count
  subnet_id       = element(var.aws_subnet_slo, count.index)
  security_groups = [ var.aws_sg_allow_slo_traffic ]
  tags = {
    Name = format("%s-pub-eni-%d", var.f5xc_cluster_name, count.index)
    Creator = var.aws_owner_tag
  }
}

resource "aws_network_interface" "sm_sli_eni" {
  count           = length(var.aws_subnet_sli) > 0 ? var.master_node_count : 0
  subnet_id       = element(var.aws_subnet_sli, count.index)
  security_groups = [ var.aws_sg_allow_sli_traffic ]

  tags = {
    Name = format("%s-priv-eni-%d", var.f5xc_cluster_name, count.index)
    Creator = var.aws_owner_tag
  }
}

resource "aws_eip" "sm_pub_ips" {
  count             = var.master_node_count
}

resource "aws_eip_association" "master_vm" {
  count                = var.master_node_count
  network_interface_id = aws_network_interface.sm_slo_eni[count.index].id
  allocation_id        = aws_eip.sm_pub_ips[count.index].id

  depends_on = [aws_instance.master_vm]
}
