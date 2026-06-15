# To get the current availability zones
data "aws_availability_zones" "zones" {

  state = "available"
  
}

data "aws_caller_identity" "current" {}


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


  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = data.aws_availability_zones.zones.names[0]
  map_public_ip_on_launch = true
}


resource "aws_route_table" "rt" {


    vpc_id = aws_vpc.vpc.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
    }

    route {
      cidr_block = "10.10.0.0/24"
      network_interface_id = aws_instance.wg_ec2.primary_network_interface_id
    }
}

resource "aws_route_table_association" "pubic_rt" {


    subnet_id = aws_subnet.public.id
    route_table_id = aws_route_table.rt.id
  
}

# VPC endpoints for future use
resource "aws_vpc_endpoint" "s3" {
  vpc_id = aws_vpc.vpc.id
  service_name = "com.amazonaws.${var.region_name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = aws_route_table.rt[*].id
}

resource "aws_vpc_endpoint" "cloudwatch_logs" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region_name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpcs.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region_name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpcs.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sns" {
  vpc_id              = aws_vpc.vpc.id
  service_name        = "com.amazonaws.${var.region_name}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpcs.id]
  private_dns_enabled = true
}


# Security Groups

# Security group for ec2
resource "aws_security_group" "wg" {
  vpc_id = aws_vpc.vpc.id


  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
  ingress {
    from_port = 51820
    to_port = 51820
    protocol = "udp"
    cidr_blocks =  ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "vpcs" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_groups = [aws_security_group.wg.id]

  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Elastic IP
resource "aws_eip" "wg_gateway" {
  domain = "vpc"

}

resource "aws_eip_association" "wg_gateway" {
  instance_id = aws_instance.wg_ec2.id
  allocation_id = aws_eip.wg_gateway.id
}


# Ec2 Instance
resource "aws_instance" "wg_ec2" {
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public.id

  source_dest_check = false
  vpc_security_group_ids = [aws_security_group.wg.id]
  associate_public_ip_address = true

  key_name = aws_key_pair.wg_key.key_name



  user_data = templatefile("${path.module}/scripts/wg_bootstrap.sh", {

    wg_interface_address = "10.10.0.2/24" 
    wg_private_key = var.wg_private_keys # Ec2 Private Key
    wg_peer_public_key = var.on_prem_public_key # On prem Public key
    wg_peer_allowed_ips = "10.10.0.1/32"
  })
}

resource "aws_key_pair" "wg_key" {
  key_name = "wg-key"
  public_key = var.ec2_pub_key
}





