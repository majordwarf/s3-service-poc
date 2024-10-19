variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "target_group_arn" {
  type = string
}

resource "aws_launch_template" "s3_launch_template" {
  name_prefix   = "s3-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [var.security_group_id]
  }
}

resource "aws_autoscaling_group" "s3_asg" {
  desired_capacity    = 2
  max_size            = 4
  min_size            = 1
  target_group_arns   = [var.target_group_arn]
  vpc_zone_identifier = [var.subnet_id]

  launch_template {
    id      = aws_launch_template.s3_launch_template.id
    version = "$Latest"
  }
}
