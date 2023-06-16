# VPC
resource "aws_vpc" "foododo" {
  cidr_block = "10.0.0.0/16"

  tags = {
    name       = "aws_vpc foododo"
    managed_by = "terraform"
  }
}

# IGW attach to VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.foododo.id

  tags = {
    name       = "aws_internet_gateway igw"
    managed_by = "terraform"
  }
}

# Public
# Subnet - Public 
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.foododo.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    name       = "aws_subnet public"
    managed_by = "terraform"
  }
}

# Route tables - Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.foododo.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    name       = "aws_route_table public"
    managed_by = "terraform"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Private
# Subnet - Private 
resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.foododo.id
  cidr_block = "10.0.2.0/24"

  tags = {
    name       = "aws_subnet private"
    managed_by = "terraform"
  }
}

# NAT gateway - Private subnet
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    name       = "aws_eip nat"
    managed_by = "terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    name       = "aws_nat_gateway nat"
    managed_by = "terraform"
  }
}

# Route tables - Private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.foododo.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    name       = "aws_route_table private"
    managed_by = "terraform"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
