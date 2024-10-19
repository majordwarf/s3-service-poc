variable "vpc_id" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "alb_name" {
  type = string
}

variable "tg_name" {
  type = string
}

variable "domain_name" {
  type = string
}

resource "aws_lb" "s3_alb" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnets
}

resource "aws_lb_target_group" "s3_tg" {
  name     = var.tg_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_listener" "s3_https_listener" {
  load_balancer_arn = aws_lb.s3_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.s3_cert.arn != null ? data.aws_acm_certificate.s3_cert.arn : aws_acm_certificate.s3_new_cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3_tg.arn
  }
}

resource "aws_route53_record" "s3_alb_dns" {
  zone_id = data.aws_route53_zone.s3_zone.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.s3_alb.dns_name
    zone_id                = aws_lb.s3_alb.zone_id
    evaluate_target_health = true
  }
}

output "alb_dns_name" {
  value = aws_lb.s3_alb.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.s3_tg.arn
}
