# set region
provider "aws" {
  region = "us-west-1"
}

# create vpc
resource "aws_vpc" "myvpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true
  tags = {
    Name = "project-two"
  }
}

# create internet gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id
}

# Define EIP for Nat
resource "aws_eip" "nat" {
}

# Define NAT Gateway
resource "aws_nat_gateway" "assessment2_nat_gateway" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.pub_sub1.id
}

# create route table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }
}

# create public subnet1
resource "aws_subnet" "pub_sub1" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.0.0/28"
  availability_zone = "us-west-1a"
  tags = {
    Name = "public1"
  }
}

# create public subnet2
resource "aws_subnet" "priv_sub" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.0.16/28"
  availability_zone = "us-west-1c"
  tags = {
    Name = "public2"
  }
}

# associate subnet1 with route table
resource "aws_route_table_association" "igw_rta1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.pub_rt.id
}

# associate subnet2 with route table
resource "aws_route_table_association" "assessment2_pvt_rt_assoc" {
  subnet_id      = aws_subnet.assessment2_pvt_subnet.id
  route_table_id = aws_route_table.assessment2_pvt_rt.id
}

# create security group1
resource "aws_security_group" "mysg1" {
  name   = "http-ssh"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# create security group
resource "aws_security_group" "mysg2" {
  name   = "ssh"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create master node
resource "aws_instance" "master" {
  key_name                    = "study-key"
  ami                         = "ami-0583a1f1cd3c11ebc"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.mysg1.id]
  subnet_id                   = aws_subnet.pub_sub1.id
  associate_public_ip_address = true
  tags = {
    Name = "master"
  }
}
# Need to go back and put one target node on pub_sub1
# Create target nodes
resource "aws_instance" "node1" {
  key_name                    = "study-key"
  ami                         = "ami-014d05e6b24240371"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.mysg2.id]
  subnet_id                   = aws_subnet.pub_sub1.id
  associate_public_ip_address = true
  tags = {
    Name = "node1"
  }
}

resource "aws_instance" "node2" {
  key_name                    = "study-key"
  ami                         = "ami-014d05e6b24240371"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.mysg.id]
  subnet_id                   = aws_subnet.priv_sub.id
  associate_public_ip_address = true
  tags = {
    Name = "node2"
  }
}
