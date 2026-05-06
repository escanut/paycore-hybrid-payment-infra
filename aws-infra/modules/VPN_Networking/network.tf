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
  map_public_ip_on_launch = true
}

resource "aws_route_table" "rt" {

    count = 2
    vpc_id = aws_vpc.vpc.id

    route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "pubic_rt" {

    count = 2
    subnet_id = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.rt[count.index].id
  
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
  security_group_ids  = [aws_security_group.wg.id]
  private_dns_enabled = true
}

# Security Groups

# Security group for ec2
resource "aws_security_group" "wg" {
  vpc_id = aws_vpc.vpc.id


  ingress{
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

# Elastic IP
resource "aws_eip" "wg_gateway" {
  domain = "vpc"

}

resource "aws_eip_association" "wg_gateway" {
  instance_id = aws_instance.wg_ec2[0].id
  allocation_id = aws_eip.wg_gateway.id
}


# Ec2 Instance
resource "aws_instance" "wg_ec2" {
  count = 2
  ami = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id = aws_subnet.public[count.index].id

  source_dest_check = false
  vpc_security_group_ids = [aws_security_group.wg.id]
  associate_public_ip_address = true

  key_name = aws_key_pair.wg_key.key_name

  user_data = templatefile("${path.module}/scripts/wg_bootstrap.sh", {

    wg_interface_address = "10.10.0.${count.index + 2}/24" 
    wg_private_key = var.wg_private_keys[count.index] # Ec2 Private Keys
    wg_peer_public_key = var.on_prem_public_key # On prem Public key
    wg_peer_allowed_ips = "10.10.0.1/32"
  })
}

resource "aws_key_pair" "wg_key" {
  key_name = "wg-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH1AJTfpQ4Ojzfopu8vsRyFdy52mDjuNG10ybP0XxgmH victorojeje@ubuntu"
}


# Lambda failover setup with iam
resource "aws_iam_role" "failover_lambda" {
  name = "paycore-wg-failover-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "failover_lambda" {
  role = aws_iam_role.failover_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeAddresses",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress"
        ]
        Resource = "*"
      },

      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "failover_lambda" {
  type = "zip"
  source_file = "${path.module}/scripts/failover.py"
  output_path = "${path.module}/scripts/failover.zip"
}

# Lambda file
resource "aws_lambda_function" "failover" {
  filename         = data.archive_file.failover_lambda.output_path
  function_name    = "paycore-wg-failover"
  role             = aws_iam_role.failover_lambda.arn
  handler          = "failover.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.failover_lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      PRIMARY_INSTANCE_ID = aws_instance.wg_ec2[0].id
      STANDBY_INSTANCE_ID = aws_instance.wg_ec2[1].id
      EIP_ALLOCATION_ID   = aws_eip.wg_gateway.id
      REGION_NAME = var.region_name
    }
  }
}


# CloudWatch alarm — triggers when node 0 fails 2 consecutive health checks
resource "aws_cloudwatch_metric_alarm" "node0_down" {
  alarm_name          = "paycore-wg-node0-down"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "WireGuard node 0 failed status check"

  dimensions = {
    InstanceId = aws_instance.wg_ec2[0].id
  }

  alarm_actions = [aws_lambda_function.failover.arn]
}

# Allow CloudWatch to invoke the Lambda
resource "aws_lambda_permission" "cloudwatch" {
  statement_id  = "AllowCloudWatchInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover.function_name
  principal     = "lambda.alarms.cloudwatch.amazonaws.com"
  source_arn    = aws_cloudwatch_metric_alarm.node0_down.arn
}