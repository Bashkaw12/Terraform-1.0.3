terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
        }
    }
}

# Configure the AWS Provider

provider "aws" {
    region = "eu-west-2"
    access_key = "#"
    secret_key = "#"
}


# 1. Create vpc

resource "aws_vpc" "main-vpc" {
    cidr_block = "10.0.0.0/16"

    tags = {
        Name = "production"
    }
}

# 2. Create Internet Gateway

resource "aws_internet_gateway" "prod-gateway" {
    vpc_id     = aws_vpc.main-vpc.id

    tags = {
        Name = "prod-gw"
    }
}

# 3. Create Custome Route Table

resource "aws_route_table" "prod-route-table" {
    vpc_id     = aws_vpc.main-vpc.id

    route {
    cidr_block = "0.0.0.0/0" // default route 
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-gateway.id
  }

  tags = {
    Name = "prod-route"
  }
}


# 4. Create a subnet

resource "aws_subnet" "prod-subnet-1" {
    vpc_id     = aws_vpc.main-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "eu-west-2a"

    tags = {
        Name = "prod-subnet"
    }
}

# 5. Associate subnet with Route table 

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.prod-subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create Security Group to allow port 22 access to connect and change, 80, 443 to allow Http and Https trafic

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

   ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

   ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an IP in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.prod-subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

#   attachment {
#     instance     = aws_instance.test.id
#     device_index = 1

#   }
}

# 8. Assign an elastic IP (Public Ip address) to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.prod-gateway]
}

output "server_public_ip" {
    value = aws_eip.one.public_ip
    # This will get the property of public_ip and print it out into console when runned apply withou using show 
}

# 9. Create Linux Ubuntu server and install/enable apache2


resource "aws_instance" "Web-server-instance" {
ami               = "ami-0194c3e07668a7e36"
instance_type     = "t2.micro"
availability_zone = "eu-west-2a"
key_name          = "DevOps-main-key"

network_interface {
        device_index           = 0
        network_interface_id   = aws_network_interface.web-server-nic.id
    }

user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y 
            sudo systemctl start apache2
            sudo bash -c 'echo My very first Terraform web server > /var/www/html/index.html'
            EOF

tags = {
    Name = "Web-server"

    
}
}







