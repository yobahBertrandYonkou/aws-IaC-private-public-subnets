provider "aws" {
    version = "~> 2.0"
    region = "ap-south-1"
    profile = "bmbterra"
}

//create a vpc
resource "aws_vpc" "bmbvpc"{
  cidr_block = "192.168.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = true
  tags = {
    Name = "bmbvpc"
  }
}


//security group
resource "aws_default_security_group" "default" {
  depends_on = [aws_vpc.bmbvpc]
  vpc_id      = aws_vpc.bmbvpc.id

  ingress {
    description = "allow http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "allow ssh"
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
    Name = "default"
  }
}


//create subnet
resource "aws_subnet" "subnetpriv"{
  depends_on = [aws_vpc.bmbvpc]
  vpc_id = aws_vpc.bmbvpc.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private_subnet"
  }
}

resource "aws_subnet" "subnetpub"{
  depends_on = [aws_vpc.bmbvpc]
  vpc_id = aws_vpc.bmbvpc.id
  cidr_block = "192.168.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "public_subnet"
  }
}

//create IGW
resource "aws_internet_gateway" "igw1"{
  depends_on = [aws_vpc.bmbvpc, aws_subnet.subnetpub]
  vpc_id = aws_vpc.bmbvpc.id
  
  tags = {
    Name = "bmbigw1"
  }
}


//create a route table and a route
resource "aws_route_table" "routetb1"{
  depends_on = [aws_internet_gateway.igw1]
  vpc_id = aws_vpc.bmbvpc.id

  route{
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw1.id
  }

  tags = {
    Name = "bmbroutetb"
  }
}

//associate subnet with route table
resource "aws_route_table_association" "rtbassoc1"{
  depends_on = [aws_route_table.routetb1]
  subnet_id = aws_subnet.subnetpub.id
  route_table_id = aws_route_table.routetb1.id
}

//launching database instance
resource "aws_instance" "bmbdbpriv" {
  depends_on = [aws_instance.wordpress]
  ami = "ami-76166b19"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnetpriv.id
  associate_public_ip_address = false
  availability_zone = aws_subnet.subnetpriv.availability_zone
  key_name = "t3"

  tags = {
    "Name" = "DB_Private"
  }
}

//launching wordpress
resource "aws_instance" "wordpress" {
  depends_on = [aws_route_table_association.rtbassoc1]
  ami = "ami-052c08d70def0ac62"
  instance_type = "t2.micro"
  subnet_id = aws_subnet.subnetpub.id
  availability_zone = aws_subnet.subnetpub.availability_zone
  key_name = "t3"
  associate_public_ip_address = true
  
  connection {
    type = "ssh"
    user = "ec2-user"
    host = aws_instance.wordpress.public_ip
    private_key = file("C:\\Users\\Mishan Regmi\\Desktop\\terratask3\\t3.pem")
  }

  provisioner "remote-exec" {
    inline = [
      "sudo dnf install php-mysqlnd php-fpm httpd tar curl php-json -y",
      "sudo yum install php -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd",
      "sudo curl https://wordpress.org/latest.tar.gz --output wordpress.tar.gz",
      "sudo tar xf wordpress.tar.gz",
      "sudo cp -r wordpress /var/www/html",
      "sudo setenforce 0"
    ]
  }


  tags = {
    "Name" = "WordPress_Public"
  }
}