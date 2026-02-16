// use default security group
resource "aws_default_security_group" "default-sg" {
    vpc_id = var.vpc_id

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
  name = var.image_name
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
    subnet_id = var.subnet_id
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

    user_data = file("${path.module}/entry-script.sh")

    // execute the script when user_data block is changed
    user_data_replace_on_change = true

    tags = {
        Name: "${var.env_prefix}-server"
    }

}