resource "aws_vpc" "sm_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = local.vpc_name
  }
}

resource "aws_subnet" "sm_public_subnet" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.sm_vpc.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.ec2_azs, count.index)

  tags = {
    Name = "${local.vpc_name}-pubsubnet-${count.index + 1}"
  }
}

resource "aws_subnet" "sm_private_subnet" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.sm_vpc.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.ec2_azs, count.index)

  tags = {
    Name = "${local.vpc_name}-prisubnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.sm_vpc.id

  tags = {
    Name = local.internet_gw_name
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.sm_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = local.igw_route_name
  }
}

resource "aws_route_table_association" "pub_subnet_rt_join" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.sm_public_subnet[*].id, count.index)
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "sm_sg_part_1" {
  name   = local.security_grp_name_1
  vpc_id = aws_vpc.sm_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = var.allowed_cidrs
  }

  tags = {
    Name = local.security_grp_name_1
  }
}

resource "aws_security_group" "sm_sg_part_2" {
  name   = local.security_grp_name_2
  vpc_id = aws_vpc.sm_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.re_ce_allowed_cidrs
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.security_grp_name_2
  }
}

resource "aws_network_interface" "sm_public_eni" {
  count           = var.ec2_instances_count
  subnet_id       = element(aws_subnet.sm_public_subnet[*].id, count.index)
  security_groups = [
    aws_security_group.sm_sg_part_1.id,
    aws_security_group.sm_sg_part_2.id
  ]

  tags = {
    Name = "${var.prefix}-${random_id.rand_id.hex}-pub-eni-${count.index + 1}"
  }
}

resource "aws_network_interface" "sm_private_eni" {
  count           = var.ec2_instances_count
  subnet_id       = element(aws_subnet.sm_private_subnet[*].id, count.index)
  security_groups = [
    aws_security_group.sm_sg_part_1.id,
    aws_security_group.sm_sg_part_2.id
  ]

  tags = {
    Name = "${var.prefix}-${random_id.rand_id.hex}-priv-eni-${count.index + 1}"
  }
}

resource "aws_eip" "sm_pub_ips" {
  count = var.ec2_instances_count
}

resource "aws_eip_association" "sm_eips" {
  count                = var.ec2_instances_count
  network_interface_id = aws_network_interface.sm_public_eni[count.index].id
  allocation_id        = aws_eip.sm_pub_ips[count.index].id

  depends_on = [aws_instance.sm_ec2_instances]
}
