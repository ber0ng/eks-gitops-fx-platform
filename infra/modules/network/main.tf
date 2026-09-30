locals {
  az_count  = length(var.azs)
  nat_count = var.single_nat_gateway ? 1 : local.az_count

  private_subnets  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets   = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, 48 + i)]
  database_subnets = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr, 8, 64 + i)]
}


# VPC 
resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

resource "aws_default_security_group" "default_sg" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-default-sg"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Subnets
resource "aws_subnet" "public_subnets" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.vpc_name}-public-${var.azs[count.index]}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = local.az_count
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                              = "${var.vpc_name}-private-${var.azs[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "database_subnets" {
  count             = local.az_count
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = local.database_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${var.vpc_name}-database-${var.azs[count.index]}"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.vpc_name}-db-subnet-group"
  subnet_ids = aws_subnet.database_subnets[*].id

  tags = {
    Name = "${var.vpc_name}-db-subnet-group"
  }
}

# NAT
resource "aws_eip" "nat_eip" {
  count  = local.nat_count
  domain = "vpc"

  tags = {
    Name = "${var.vpc_name}-nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = local.nat_count
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id

  tags = {
    Name = "${var.vpc_name}-nat-gateway-${count.index}"
  }
}

# Routing
// Public route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  count          = local.az_count
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

// Private route tables: one per NAT gateway (a single shared one when single_nat_gateway is true)
resource "aws_route_table" "private_route_table" {
  count  = local.nat_count
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway[count.index].id
  }
  tags = {
    Name = "${var.vpc_name}-private-rt-${count.index}"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  count          = local.az_count
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_route_table[var.single_nat_gateway ? 0 : count.index].id
}

// Database route table
resource "aws_route_table" "database_route_table" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "${var.vpc_name}-database-rt"
  }
}

resource "aws_route_table_association" "database_route_table_association" {
  count          = local.az_count
  subnet_id      = aws_subnet.database_subnets[count.index].id
  route_table_id = aws_route_table.database_route_table.id
}
