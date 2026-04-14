variable "name"             { type = string }
variable "vpc_id"           { type = string }
variable "subnet_ids"       { type = list(string) }
variable "sg_id"            { type = string }
variable "api_instance_ids" { type = list(string) }
variable "project_tag"      { type = string  default = "peliculas-api" }

# ── Application Load Balancer ─────────────────────────────────────────────────
# Reemplaza a haproxy-master + haproxy-backup del docker-compose.
# AWS ALB tiene HA nativa: no necesitas dos instancias de haproxy.
resource "aws_lb" "this" {
  name               = var.name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.sg_id]
  subnets            = var.subnet_ids

  tags = {
    Name    = var.name
    Project = var.project_tag
  }
}

# ── Target Group: apunta al puerto 5000 de Flask ─────────────────────────────
# CAMBIO vs versión recetas: puerto 8000 → 5000
# El health check apunta a /health (definido en routes.py)
resource "aws_lb_target_group" "api" {
  name        = "${var.name}-tg"
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = {
    Name    = "${var.name}-tg"
    Project = var.project_tag
  }
}

# ── Registrar instancias API en el Target Group ───────────────────────────────
resource "aws_lb_target_group_attachment" "api" {
  count            = length(var.api_instance_ids)
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = var.api_instance_ids[count.index]
  port             = 5000
}

# ── Listener HTTP en puerto 80 → forward al Target Group ─────────────────────
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

output "dns_name" { value = aws_lb.this.dns_name }
