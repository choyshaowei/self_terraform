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
  cidr_block              = "10.0.${count.index}.0/24"
  count                   = length(data.aws_availability_zones.available.names)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
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
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private
# Subnet - Private 
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.foododo.id
  cidr_block        = "10.0.${count.index + 100}.0/24"
  count             = length(data.aws_availability_zones.available.names)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    name       = "aws_subnet private"
    managed_by = "terraform"
  }
}

# NAT gateway - Private subnet
resource "aws_eip" "nat" {
  count  = length(aws_subnet.public)
  domain = "vpc"

  tags = {
    name       = "aws_eip nat"
    managed_by = "terraform"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = length(aws_subnet.public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    name       = "aws_nat_gateway nat"
    managed_by = "terraform"
  }
}


# Route tables - Private
resource "aws_route_table" "private" {
  count  = length(aws_nat_gateway.nat)
  vpc_id = aws_vpc.foododo.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    name       = "aws_route_table private ${count.index}"
    managed_by = "terraform"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
