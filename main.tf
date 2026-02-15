provider "aws" {
    region = "ca-central-1"
}

variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
// variable my_public_key {}
variable public_key_location {}
variable private_key_location {}

// "provider_resourceType" "the name we can define"
resource "aws_vpc" "myapp-vpc" {
    // private IP address range
    cidr_block = var.subnet_cidr_block

    // set up the name for the resource
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

// aws_subnet
resource "aws_subnet" "myapp-subnet-1" {
    // creating a resource for a non existing resource
    vpc_id = aws_vpc.myapp-vpc.id
    cidr_block = var.subnet_cidr_block
    availability_zone = var.avail_zone

    // set up the name for the resource
    tags = {
        Name: "${var.env_prefix}-subnet-1"
    }
}

// Below is the approach of creating new route table

// route table
# resource "aws_route_table" "myapp_route_table" {
#     vpc_id = aws_vpc.myapp-vpc.id

#     route {
#         cidr_block = "0.0.0.0/0"
#         gateway_id = aws_internet_gateway.myapp-igw.id
#     }
#     tags = {
#         Name: "${var.env_prefix}-rtb"
#     }
# }

// internet gateway
# resource "aws_internet_gateway" "myapp-igw" {
#     vpc_id = aws_vpc.myapp-vpc.id
# }

# // route table association
# resource "aws_route_table_association" "a-rtb-subnet" {
#   subnet_id = aws_subnet.myapp-subnet-1.id
#   route_table_id = aws_route_table.myapp_route_table.id
# }

// Below is the approach to use existing route table

// internet gateway
resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id
    tags = {
      Name: "${var.env_prefix}-igw"
    }
}

// route table
resource "aws_default_route_table" "main-rtb" {
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.myapp-igw.id
    }
    tags = {
        Name: "${var.env_prefix}-main-rtb"
    }
}

// below approach is creating security group 
// security group
# resource "aws_security_group" "myapp-sg" {
#     name = "myapp-sg"
#     vpc_id = aws_vpc.myapp-vpc.id

#     // incoming traffic
#     // 1.SSH into EC2
#     // 2.access from browser
#     ingress {
#         // from and to means a range: 22~22
#         from_port = 22
#         to_port = 22
#         protocol = "TCP"
#         // your IP address
#         cidr_blocks = [var.my_ip]
#     }

#     ingress {   
#         from_port = 8080
#         to_port = 8080
#         protocol = "TCP"
#         cidr_blocks = ["0.0.0.0/0"]
#     }

#     // outgoing traffic
#     // 1.installtions
#     // 2.fetch Docker Image
#     egress {
#         from_port = 0
#         to_port = 0
#         // "-1" means any
#         protocol = "-1"
#         cidr_blocks = ["0.0.0.0/0"]
#         // allow access to vpc endpoint
#         prefix_list_ids = []
#     } 

#     tags = {
#         Name: "${var.env_prefix}-sg"
#     }
# }

// use default security group
resource "aws_default_security_group" "default-sg" {
    vpc_id = aws_vpc.myapp-vpc.id

    // incoming traffic
    // 1.SSH into EC2
    // 2.access from browser
    ingress {
        // from and to means a range: 22~22
        from_port = 22
        to_port = 22
        protocol = "TCP"
        // your IP address
        cidr_blocks = [var.my_ip]
    }

    ingress {   
        from_port = 8080
        to_port = 8080
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
    }

    // outgoing traffic
    // 1.installtions
    // 2.fetch Docker Image
    egress {
        from_port = 0
        to_port = 0
        // "-1" means any
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        // allow access to vpc endpoint
        prefix_list_ids = []
    } 

    tags = {
        Name: "${var.env_prefix}-default-sg"
    }
}

// image location
data "aws_ssm_parameter" "al2023_x86" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

# validate public ip
output "ec2_public_ip" {
  value = aws_instance.myapp-server.public_ip
}

// key pair for ssh
resource "aws_key_pair" "ssh-key" {
    key_name = "server-key"
    // reference to file, use"file()" and it will read from the file 
    public_key = file(var.public_key_location)
}

resource "aws_instance" "myapp-server" {
    ami = data.aws_ssm_parameter.al2023_x86.value
    instance_type = var.instance_type

    // optional attributes
    // if not expilicit it, new instance will be created in default everything
    subnet_id = aws_subnet.myapp-subnet-1.id
    vpc_security_group_ids = [aws_default_security_group.default-sg.id]
    availability_zone = var.avail_zone
    // for accessing from broswer and SSH access
    associate_public_ip_address = true

    // associate the kay with the server
    key_name = aws_key_pair.ssh-key.key_name
// entry point script executed at EC2 server when EC2 initiated
// EOF marks the beginning and end of a multi-line block of text
# user_data = <<EOF
# #!/bin/bash

# dnf update -y
# dnf install -y docker
# systemctl start docker
# systemctl enable docker
# usermod -aG docker ec2-user
# docker run -d --name nginxserver -p 8080:80 nginx

# EOF

// user_data = file("entry-script.sh")

    // define the coneection expilictly to the remote server, specific to provisioner
    connection {
        type = "ssh"
        host = self.public_ip
        user = "ec2-user"
        private_key = file(var.private_key_location)
    }

    // file provisioner for copying local script to remote server
    provisioner "file" {
        source = "entry-script.sh"
        destination = "/home/ec2-user/entry-script-on-ec2.sh"
    }

    // terraform function for script
    provisioner "remote-exec" {

        // 1st way to execute script
        // inline = ["/home/ec2-user/entry-script-on-ec2.sh"]

        // 2nd way to execute script
        script = "entry-script.sh"
    }

    // local provisioner
    # provisioner "local-exec" {
    #     command = "echo ${self.public_ip} > output.txt"
    # }

    // execute the script when user_data block is changed
    user_data_replace_on_change = true

    tags = {
        Name: "${var.env_prefix}-server"
    }

}