# Generate a client key used for clients. This key will be created once and can be reused for all instances, simplifying key management while ensuring secure access to the EC2 instances. The private key will be saved locally in PEM format with appropriate permissions to ensure security.
resource "tls_private_key" "smv2_client_key" {
    algorithm = "RSA"
    rsa_bits  = 4096
}

resource "aws_key_pair" "smv2_client_key" {
    key_name   = "smv2-client-key"
    public_key = tls_private_key.smv2_client_key.public_key_openssh
}

resource "local_file" "smv2_client_pem" {
    content  = tls_private_key.smv2_client_key.private_key_pem
    filename = "${path.root}/smv2-client-key.pem"
    file_permission = "0400"
}

# This will fetch the latest Ubuntu 24.04 AMI for the specified region, which will be used for client instances. The pattern can be adjusted to fetch different versions or types of Ubuntu images as needed.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = [var.ubuntu_ami_name_pattern]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# load the cloud-init template for client instances.
data "template_file" "cloud_init" {
  template = file("${path.module}/templates/cloud-init.yaml")
}

# Network interface for client instances created in the same SMv2 VPC, with one public and one private interface per client instance. The public interfaces will be associated with Elastic IPs for external access, while the private interfaces will allow communication within the VPC and with the server instances.
resource "aws_network_interface" "sm_client_public_eni" {
  count           = var.client_ec2_instances_count
  subnet_id       = var.public_subnet_ids[count.index]
 security_groups = [
    var.security_group_id_1,
    var.security_group_id_2
  ]

  tags = {
    Name = "${var.project_prefix}-${var.random_id}-client-pub-eni"
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
}

resource "aws_network_interface" "sm_client_private_eni" {
  count           = var.client_ec2_instances_count
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [
    var.security_group_id_1,
    var.security_group_id_2
  ]

  tags = {
    Name = "${var.project_prefix}-${var.random_id}-client-priv-eni"
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
}

resource "aws_eip" "sm_client_pub_ips" {
  count             = var.client_ec2_instances_count
  tags = {
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
}

resource "aws_eip_association" "sm_client_eips" {
  count                = var.client_ec2_instances_count
  network_interface_id = aws_network_interface.sm_client_public_eni[count.index].id
  allocation_id        = aws_eip.sm_client_pub_ips[count.index].id

  depends_on = [aws_instance.smv2_client_instances]
}

# This resource block creates the client EC2 instances using the latest Ubuntu 24.04 AMI. Each instance is configured with a public and private network interface, and is tagged for identification and management purposes. The instances will be accessible via the associated Elastic IPs, allowing for external access while maintaining secure communication within the VPC.

resource "aws_instance" "smv2_client_instances" {
  count         = var.client_ec2_instances_count
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.client_instance_type

  root_block_device {
    volume_size = var.client_ec2_disk_size
  }

  network_interface {
    network_interface_id = element(aws_network_interface.sm_client_public_eni[*].id, count.index)
    device_index         = 0
  }

  network_interface {
    network_interface_id = element(aws_network_interface.sm_client_private_eni[*].id, count.index)
    device_index         = 1
  }

  user_data = data.template_file.cloud_init.rendered

  key_name = aws_key_pair.smv2_client_key.key_name

  tags = {
    Name = "${var.project_prefix}-${var.random_id}-client-${count.index}"
    area = "smsv2-automation"
    UserEmail = var.user_email
    EnvironmentName = var.env
    CostCenter = var.user_costcenter
    ManagerEmail = var.user_manager
    Team = var.user_team
  }
  
}