terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket  = "my-terraform-state-bucket-6820"
    key     = "ec2/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-2"
}


resource "aws_vpc" "ec2-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "ec2-vpc"
  }
}

# Internet Gateway for Internet Access
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.ec2-vpc.id

  tags = {
    Name = "main"
  }
}

# Public Subnet1 for public resources
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.ec2-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-1"
  }
}

# Public Subnet2 for public resources
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.ec2-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-2b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}

# Private subnet1 for private resources
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.ec2-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-2a"

  tags = {
    Name = "private-subnet-1"
  }
}

# Private subnet2 for private resources
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.ec2-vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-2b"

  tags = {
    Name = "private-subnet-2"
  }
}



resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.gw]
  tags = {
    Name = "nat-eip"
  }
}


# NAT Gateway for public subnet 1
resource "aws_nat_gateway" "nat_gw" {
  allocation_id     = aws_eip.nat.id
  subnet_id         = aws_subnet.public_subnet_1.id
  connectivity_type = "public"

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}



# Route Table for public subnet 
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.ec2-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }



  tags = {
    Name = "public-route-table"
  }
}


# Route Table for private subnet 2

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.ec2-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }



  tags = {
    Name = "private-route-table"
  }
}

# Associate the public subnet 1 with the route table
resource "aws_route_table_association" "public_subnet_1_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate the public subnet 2 with the route table
resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Associate the private subnet 1 with the route table
resource "aws_route_table_association" "private_subnet_1_association" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_2_association" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_route_table.id
}

# EC2 Security Group
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.ec2-vpc.id

  tags = {
    Name = "allow_tls"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_file" "setup-git" {
  template = file("setup-git.tpl")
}

resource "aws_instance" "netflix_app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_subnet_1.id
  key_name               = "abc"
  vpc_security_group_ids = [aws_security_group.allow_tls.id]

  tags = {
    Name = "Hello-Ec2"
  }

  user_data = data.template_file.setup-git.rendered

  

}





output "vp_id" {
  value = aws_vpc.ec2-vpc.id

}


output "public_subnets" {
  value = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

output "private_subnets" {
  value = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]
}