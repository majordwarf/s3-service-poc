# Provider configuration
provider "aws" {
  region = var.region
}

# Variables
variable "region" {
  type    = string
  default = "us-west-2"
}

variable "domain_name" {
  type    = string
  default = "getmesmer.xyz"
}

# Local variables
locals {
  vpc_cidr_block           = "10.0.0.0/16"
  private_subnet_cidr_block = "10.0.1.0/24"
  ami_id                   = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type            = "t3a.small"
  alb_name                 = "s3-alb"
  tg_name                  = "s3-tg"
  sg_instance_name         = "s3-instance-sg"
  sg_alb_name              = "s3-alb-sg"
}

# Modules
module "vpc" {
  source = "./modules/vpc"
  vpc_cidr_block = local.vpc_cidr_block
  private_subnet_cidr_block = local.private_subnet_cidr_block
  region = var.region
}

module "security_groups" {
  source = "./modules/security_groups"
  vpc_id = module.vpc.vpc_id
  sg_instance_name = local.sg_instance_name
  sg_alb_name = local.sg_alb_name
}

module "alb" {
  source = "./modules/alb"
  vpc_id = module.vpc.vpc_id
  subnets = [module.vpc.private_subnet_id]
  security_group_id = module.security_groups.alb_sg_id
  alb_name = local.alb_name
  tg_name = local.tg_name
  domain_name = var.domain_name
}

module "autoscaling" {
  source = "./modules/autoscaling"
  vpc_id = module.vpc.vpc_id
  subnet_id = module.vpc.private_subnet_id
  ami_id = local.ami_id
  instance_type = local.instance_type
  security_group_id = module.security_groups.instance_sg_id
  target_group_arn = module.alb.target_group_arn
}

module "acm" {
  source = "./modules/acm"
  domain_name = var.domain_name
}

# Outputs
output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "certificate_arn" {
  value = module.acm.certificate_arn
}
