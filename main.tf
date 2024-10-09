terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"  # Replace with your AWS region
}

resource "aws_vpc" "k8s_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "k8s_subnet" {
  vpc_id     = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2c"
  map_public_ip_on_launch = true
}

resource "aws_security_group" "k8s_sg" {
  vpc_id = aws_vpc.k8s_vpc.id

  # SSH Traffic
  ingress {
    description = "SSH"
    from_port   = 22  # SSH client port is not a fixed port
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #allow web traffic. 46.64.73.251/32
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Kubernetes API access
  }
  
  ingress {
    from_port   = 80
    to_port     = 30000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP access on port 80
  }
  
#  ingress {
#    from_port   = 3000
#    to_port     = 3000
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]  # Allow HTTP access on port 80
#  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "k8s_master" {
  ami           = "ami-0992959aaea5762e8"  # Use a Kubernetes-compatible AMI
  instance_type = "t2.small"
  subnet_id     = aws_subnet.k8s_subnet.id
  security_groups = [aws_security_group.k8s_sg.id]
  key_name = "terraform-k8s-key"

  tags = {
    Name = "K8s-Master"
  }

  # Use provisioners to upload and execute your scripts
  provisioner "file" {
    source      = "master_install.sh"  # Path to local script
    destination = "/home/ec2-user/master_install.sh"  # Destination on instance
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/terraform-k8s-key.pem")
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/master_install.sh",
      "/home/ec2-user/master_install.sh"
    ]
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/terraform-k8s-key.pem")
      host        = self.public_ip
    }
  }

  #  user_data = file("master_install.sh")
}

resource "aws_instance" "k8s_worker" {
  count = 2
  ami           = "ami-0992959aaea5762e8"  # Use a Kubernetes-compatible AMI
  instance_type = "t2.small"
  subnet_id     = aws_subnet.k8s_subnet.id
  security_groups = [aws_security_group.k8s_sg.id]
  key_name = "terraform-k8s-key"
  
  tags = {
    Name = "K8s-Worker-${count.index + 1}"
  }

  user_data = file("worker_install.sh")
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "K8s-Internet-Gateway"
  }
}

resource "aws_route_table" "k8s_route_table" {
  vpc_id = aws_vpc.k8s_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s_igw.id
  }

  tags = {
    Name = "K8s-Route-Table"
  }
}


resource "aws_route_table_association" "k8s_subnet_association" {
  subnet_id      = aws_subnet.k8s_subnet.id
  route_table_id = aws_route_table.k8s_route_table.id
}


output "master_public_ip" {
  description = "Public IP of the master node"
  value       = aws_instance.k8s_master.public_ip
}

output "worker_public_ips" {
  description = "Public IPs of the worker nodes"
  value       = aws_instance.k8s_worker.*.public_ip
}
