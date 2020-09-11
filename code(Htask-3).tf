  #Providing login credentials to aws
provider "aws" {
  region     = "ap-south-1"
  profile    = "jack" 
 
}

#Creating private key
resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits = 4096
}
resource "aws_key_pair" "generated_key" {
 key_name = "wordpress_key"
 public_key = tls_private_key.key.public_key_openssh

depends_on = [
    tls_private_key.key
]
}

#Downloading priavte key
resource "local_file" "file" {
    content  = tls_private_key.key.private_key_pem
    filename = "C:/Users/NMC/Desktop/task-3/wordpress_key.pem"
    file_permission = "0400"
}
 
#creating vpc
resource "aws_vpc" "new-vpc" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "new-vpc"
  }
}

#creating subnet
resource "aws_subnet" "public" {
  depends_on = [aws_vpc.new-vpc, ]
  vpc_id     = aws_vpc.new-vpc.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch  =  true
  tags = {
    Name = "Public"
  }
}

resource "aws_subnet" "private" {
  depends_on = [ aws_vpc.new-vpc,
                  aws_subnet.public, ]
  vpc_id     = aws_vpc.new-vpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"
    tags = {
    Name = "Private"
  }
}

resource "aws_internet_gateway" "int-gw" {
  depends_on = [ aws_vpc.new-vpc,
                   aws_subnet.public, ]
  vpc_id = "${aws_vpc.new-vpc.id}"

  tags = {
    Name = "new-gw"
  }
}

#creating routing table
resource "aws_route_table" "new-rt" {
  depends_on = [aws_internet_gateway.int-gw, ]
  vpc_id = aws_vpc.new-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int-gw.id
    }
   tags = {
    Name = "routing table"
  }
} 
resource "aws_route_table_association" "new" {
   depends_on = [ aws_route_table.new-rt, ]
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.new-rt.id
}

#creating security group
resource "aws_security_group" "wordpress-sg" {
 depends_on = [ aws_vpc.new-vpc, ]
  name        = "wordpress-sg"
  description = "All HTTP,SSH inbound traffic"
  vpc_id      = "${aws_vpc.new-vpc.id}"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   ingress {
    description = "Allow SSH"
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

  tags = {
    Name = "wordpress-sg"
  }
}

resource "aws_security_group" "mysql-sg" {
  depends_on = [ aws_vpc.new-vpc,
                   aws_security_group.wordpress-sg, ]
  name        = "mysql_sg"
  description = "Allow Wordpress"
  vpc_id      = aws_vpc.new-vpc.id

  ingress {
    description = "MYSQL from VPC"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = ["${aws_security_group.wordpress-sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Mysql-sg"
  }
}

resource "aws_instance" "wordpress" {
 depends_on = [   aws_subnet.public,
                  aws_security_group.wordpress-sg, ]
  ami           = "ami-02b9afddbf1c3b2e5"
  instance_type = "t2.micro"
  key_name = "wordpress_key"
  vpc_security_group_ids = ["${aws_security_group.wordpress-sg.id}"]
  subnet_id = aws_subnet.public.id
 tags = {
    Name = "WordPress"
  }
}

resource "aws_instance" "mysql" {
depends_on = [    aws_subnet.private,
                  aws_security_group.mysql-sg, ]
  ami           = "ami-0d8b282f6227e8ffb"
  instance_type = "t2.micro"
  key_name = "wordpress_key"
  vpc_security_group_ids = ["${aws_security_group.mysql-sg.id}"]
  subnet_id = aws_subnet.private.id
 tags = {
    Name = "Mysql"
  }
}
