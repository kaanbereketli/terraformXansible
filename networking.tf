locals {
    azs = data.aws_availability_zones.available.names
}

data "aws_availability_zones" "available" {}

resource "random_id" "random" {
    byte_length = 2
}

resource "aws_vpc" "green_vpc" {
    cidr_block = var.vpc_cidr
    enable_dns_hostnames = true
    enable_dns_support = true
    
    tags = {
        Name = "green-vpc-${random_id.random.dec}"
    }
    
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_internet_gateway" "green_internet_gateway" {
    vpc_id = aws_vpc.green_vpc.id
    
    tags = {
        Name = "green-igw-${random_id.random.dec}"
    }
}

resource "aws_route_table" "green_public_rt" {
    vpc_id = aws_vpc.green_vpc.id
    
    tags = {
        Name = "green-public"
    }
}

#Anything that comes that is destined for the outside world is going to hit this route table. Also we don't have any other routes.
resource "aws_route" "default_route" {
    route_table_id = aws_route_table.green_public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.green_internet_gateway.id
    
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_default_route_table" "green_private_rt" {
    default_route_table_id = aws_vpc.green_vpc.default_route_table_id
    
    tags = {
        Name = "green_private"
    }
}

resource "aws_subnet" "green_public_subnet" {
    count = length(local.azs)
    vpc_id = aws_vpc.green_vpc.id
    cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
    map_public_ip_on_launch = true
    availability_zone = local.azs[count.index]
    
    #Since they're human readable tags it might make more sense to finance, if everything starts at 1 instead of 0 
    tags = {
        Name = "green_public-${count.index + 1}"
    }
}

#All private subnets are going to fall back to the default route table by default, so we don't need to worry about creating explicit associations 
resource "aws_subnet" "green_private_subnet" {
    count = length(local.azs)
    vpc_id = aws_vpc.green_vpc.id
    cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index + length(local.azs))
    map_public_ip_on_launch = false
    availability_zone = local.azs[count.index]
    
    #Since they're human readable tags it might make more sense to finance, if everything starts at 1 instead of 0 
    tags = {
        Name = "green_private-${count.index + 1}"
    }
}

#Route table association for public subnets
resource "aws_route_table_association" "green_public_assoc" {
    count = length(local.azs)
    subnet_id = aws_subnet.green_public_subnet[count.index].id
    route_table_id = aws_route_table.green_public_rt.id
}

resource "aws_security_group" "green_sg" {
    name = "public_sg"
    description = "Security group for public instances"
    vpc_id = aws_vpc.green_vpc.id
}

#We will allow any of the subnets that are provided within the cidrblocks here will be able to access everything that uses this security group
resource "aws_security_group_rule" "ingress_all" {
    type = "ingress"
    from_port = 0
    to_port = 65535
    protocol = "-1" #Any protocol
    cidr_blocks = [var.access_ip]
    security_group_id = aws_security_group.green_sg.id
}

resource "aws_security_group_rule" "egress_all" {
    type = "egress"
    from_port = 0
    to_port = 65535
    protocol = "-1" #Any protocol
    cidr_blocks = ["0.0.0.0/0"]
    security_group_id = aws_security_group.green_sg.id
}