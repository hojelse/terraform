provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "My VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "My internet gateway"
  }
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.1.1.0/24"
  availability_zone = "eu-central-1a"
  tags = {
    "Name" = "My subnet"
  }
}

resource "aws_route_table" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Name" = "My route table"
  }
  
  route {
    // All traffic to other addresses than the subnet
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "main" {
  subnet_id = aws_subnet.main.id
  route_table_id = aws_route_table.default.id
}

resource "aws_network_acl" "allowall" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_block = "0.0.0.0/0"
    rule_no = 200
    action = "allow"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_block = "0.0.0.0/0"
    rule_no = 100
    action = "allow"
  }
}

resource "aws_security_group" "allowall" {
  name = "My allow all security group"
  description = "Naughty sec group"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_eip" "webserver" {
  instance = aws_instance.webserver.id
  vpc = true
  depends_on = [aws_internet_gateway.main]
}

resource "aws_key_pair" "default" {
  key_name = "my-ssh-key"
  public_key = file("~/.ssh/my-ec2-key.pub")
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical's account id, who maintains ubuntu
}

resource "aws_instance" "webserver" {
  ami = data.aws_ami.ubuntu.id
  availability_zone = "eu-central-1a"
  instance_type = "t2.micro"
  key_name = aws_key_pair.default.key_name
  vpc_security_group_ids = [aws_security_group.allowall.id]
  subnet_id = aws_subnet.main.id
}

output "public_ip" {
  value = aws_eip.webserver.public_ip
}
