# VPC
resource "aws_vpc" "default" {
    cidr_block = var.vpc_cidr_block
    enable_dns_hostnames = true
    
    tags = {
       Name        = "wp-pvc-tf"
       Environment = "aws-wp-lab"
       Project     = "aws-wp-tf-poc"
       ManagedBy   = "terraform"
    }
}

# Internet Gateway
resource "aws_internet_gateway" "default" {
    vpc_id = aws_vpc.default.id

    tags = {
       Name        = "wp-igw-tf"
       Environment = "aws-wp-lab"
       Project     = "aws-wp-tf-poc"
       ManagedBy   = "terraform"
    }
}

# Subnets
resource "aws_subnet" "wp-public-a-tf" {
    vpc_id            = aws_vpc.default.id
    cidr_block        = var.public_subnet_a_cidr_block
    availability_zone = "${var.region}a"

    tags = {
       Name        = "wp-public-a-tf"
       Environment = "aws-wp-lab"
       Project     = "aws-wp-tf-poc"
       ManagedBy   = "terraform"
    }
}

resource "aws_subnet" "wp-public-b-tf" {
    vpc_id            = aws_vpc.default.id
    cidr_block        = var.public_subnet_b_cidr_block
    availability_zone = "${var.region}b"

    tags = {
       Name        = "wp-public-b-tf"
       Environment = "aws-wp-lab"
       Project     = "aws-wp-tf-poc"
       ManagedBy   = "terraform"
    }
}

resource "aws_subnet" "wp-public-c-tf" {
    vpc_id            = aws_vpc.default.id
    cidr_block        = var.public_subnet_c_cidr_block
    availability_zone = "${var.region}c"

    tags = {
       Name        = "wp-public-c-tf"
       Environment = "aws-wp-lab"
       Project     = "aws-wp-tf-poc"
       ManagedBy   = "terraform"
    }
}

# Route Tables
resource "aws_route_table" "wp-rt-public-tf" {
    vpc_id = aws_vpc.default.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.default.id
    }

    tags = {
       Name        = "wp-rt-public-tf"
       Environment = "aws-wp-lab"
       Project     = "aws-wp-tf-poc"
       ManagedBy   = "terraform"
    }
}

resource "aws_route_table_association" "a" {
    subnet_id = aws_subnet.wp-public-a-tf.id
    route_table_id = aws_route_table.wp-rt-public-tf.id
}

resource "aws_route_table_association" "b" {
    subnet_id = aws_subnet.wp-public-b-tf.id
    route_table_id = aws_route_table.wp-rt-public-tf.id
}

resource "aws_route_table_association" "c" {
    subnet_id = aws_subnet.wp-public-c-tf.id
    route_table_id = aws_route_table.wp-rt-public-tf.id
}