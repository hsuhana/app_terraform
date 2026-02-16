#!/bin/bash
dnf update -y
dnf install -y docker
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
docker run -d --name nginxserver -p 8080:80 nginx
