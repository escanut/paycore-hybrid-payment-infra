# To get the current availability zones
data "aws_availability_zones" "zones" {

  state = "available"
  
}

# We wont be hardcoding the images
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's official AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}


# VPC definition
resource "aws_vpc" "vpc" {

  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true

  # Tags are defined in environments

}


resource "aws_internet_gateway" "igw" {
  
    vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {

  count = 2
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, 1 + count.index)
  availability_zone = data.aws_availability_zones.zones.names[count.index]
  
}

resource "aws_route_table" "rt" {

    count = 2
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route" "internet" {
  
  count = 2
  route_table_id = aws_route_table.rt[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id

}

# Specifing traffic for VPN tunnel should go through the network interface
# of the Wireguard EC2 instance
resource "aws_route" "vpn_route" {

  count = 2
  route_table_id = aws_route_table.rt[count.index].id
  destination_cidr_block = "10.10.0.0/24"
  network_interface_id = aws_instance.wg_ec2[count.index].primary_network_interface_id

}


resource "aws_route_table_association" "association" {
  
  count = 2
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.rt[count.index].id
}

resource "aws_eip" "wg_eip" {

    count = 2
    domain = "vpc"
}

resource "aws_eip_association" "wg_eip_association" {
    count = 2
    instance_id = aws_instance.wg_ec2[count.index].id
    allocation_id = aws_eip.wg_eip[count.index].id

}



# We want high availability
resource "aws_instance" "wg_ec2" {

  count = 2
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  subnet_id = aws_subnet.public[count.index].id

  source_dest_check = false # So it allows wireguard traffic forwarding

  
  
  
}