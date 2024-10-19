variable "vpc_id" {
  type = string
}

variable "sg_instance_name" {
  type = string
}

variable "sg_alb_name" {
  type = string
}

resource "aws_security_group" "s3_instance_sg" {
  name        = var.sg_instance_name
  description = "Security group for S3 App EC2 instances"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.s3_alb_sg.id]
  }
}

resource "aws_security_group" "s3_alb_sg" {
  name        = var.sg_alb_name
  description = "Security group for S3 App ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "instance_sg_id" {
  value = aws_security_group.s3_instance_sg.id
}

output "alb_sg_id" {
  value = aws_security_group.s3_alb_sg.id
}
