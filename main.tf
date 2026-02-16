provider "aws" {
    region = "ca-central-1"
}

// "provider_resourceType" "the name we can define"
resource "aws_vpc" "myapp-vpc" {
    // private IP address range
    cidr_block = var.subnet_cidr_block

    // set up the name for the resource
    tags = {
        Name: "${var.env_prefix}-vpc"
    }
}

module "myapp-subnet" {
    // where's the source living
    // if it's relative path need to add "./"
    source = "./modules/subnet"

    //define variables defined in child's module
    subnet_cidr_block = var.subnet_cidr_block
    avail_zone = var.avail_zone
    env_prefix = var.env_prefix
    vpc_id = aws_vpc.myapp-vpc.id
    default_route_table_id = aws_vpc.myapp-vpc.default_route_table_id

}

module "myapp-server" {
    source = "./modules/webserver"
    vpc_id = aws_vpc.myapp-vpc.id
    my_ip = var.my_ip
    env_prefix = var.env_prefix
    image_name = var.image_name
    public_key_location = var.public_key_location
    instance_type = var.instance_type
    subnet_id = module.myapp-subnet.subnet.id
    avail_zone = var.avail_zone
}