# Declaration of variables

variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "region" {
  default = "us-east-2"      
}

#Declare the providers

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}


#data https://www.terraform.io/docs/providers/aws/d/ami.html

data "aws_ami" "ucp" {
    most_recent = true
    owners = ["amazon"]

    filter {
        name = "root-device-type"
        values = ["ebs"]

    }

    filter  {
        name = "virtualization-type"
        values = ["hvm"]
    }
}

data "aws_availability_zones" "az" {
    state = "available"
}

#Resources

resource "aws_default_vpc" "default" {}

# https://www.terraform.io/docs/providers/aws/r/security_group.html

resource "aws_key_pair" "key" {
  key_name   = "ucpkey"
  public_key = file("~/.ssh/ucp.pub")
}

resource "aws_security_group" "allow_connections" {

    name = "Nginx demo from code"
    description = "Allow ports for nginx demo"
    vpc_id = aws_default_vpc.default.id

    ingress {
        description = "SSH connection"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # You need change to your public ip
    }

    ingress {
        description = "HTTP connection"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"] # You need change to your public ip
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_eip" "ip" {
  vpc = true
}

# EC2 machine

resource "aws_instance" "nginx" {
    ami = data.aws_ami.ucp.id

    instance_type = "t2.micro"

    key_name = aws_key_pair.key.key_name

    vpc_security_group_ids = [aws_security_group.allow_connections.id]

    connection {
        type = "ssh"
        host = self.public_ip
        user = "ec2-user"
        private_key = file("~/.ssh/ucp")
    }

    provisioner "remote-exec" {
        inline = [
            "sudo yum install nginx -y",
            "sudo service nginx start"
        ]
    }

    tags = {
            Name = "UCP machine"
     }
  
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.nginx.id
  allocation_id = aws_eip.ip.id
}

#output

output "aws_instance_public_dns" {
  value = aws_instance.nginx.public_dns
}











