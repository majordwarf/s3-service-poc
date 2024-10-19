variable "vpc_cidr_block" {
  type = string
}

variable "private_subnet_cidr_block" {
  type = string
}

variable "region" {
  type = string
}

resource "aws_vpc" "s3_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "s3-vpc"
  }
}

resource "aws_subnet" "s3_private_subnet" {
  vpc_id            = aws_vpc.s3_vpc.id
  cidr_block        = var.private_subnet_cidr_block
  availability_zone = "${var.region}a"

  tags = {
    Name = "s3-private-subnet"
  }
}

resource "aws_internet_gateway" "s3_igw" {
  vpc_id = aws_vpc.s3_vpc.id

  tags = {
    Name = "s3-igw"
  }
}

resource "aws_route_table" "s3_route_table" {
  vpc_id = aws_vpc.s3_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.s3_igw.id
  }

  tags = {
    Name = "s3-route-table"
  }
}

output "vpc_id" {
  value = aws_vpc.s3_vpc.id
}

output "private_subnet_id" {
  value = aws_subnet.s3_private_subnet.id
}
