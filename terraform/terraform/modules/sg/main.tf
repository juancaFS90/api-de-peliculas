variable "vpc_id" {
  type        = string
  description = "ID de la VPC donde se crearán los Security Groups"
}

# ── ALB: acepta tráfico HTTP público ─────────────────────────────────────────
resource "aws_security_group" "alb" {
  name        = "peliculas-alb-sg"
  description = "SG del Application Load Balancer — tráfico HTTP público"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP público"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "peliculas-alb-sg" }
}

# ── API: acepta tráfico SOLO desde el ALB en puerto 5000 ─────────────────────
# CAMBIO vs versión recetas: puerto 8000 → 5000 (Flask corre en 5000)
# El app/main.py arranca con app.run(host="0.0.0.0", port=5000)
resource "aws_security_group" "api" {
  name        = "peliculas-api-sg"
  description = "SG de las instancias Flask API — solo tráfico desde el ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Flask desde ALB"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH admin — restringir a tu IP en producción"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "peliculas-api-sg" }
}

# ── MongoDB: solo desde API y Worker ────────────────────────────────────────
# No tiene IP pública; el script install_mongodb.sh hace bindIp: 0.0.0.0
# pero el SG limita quién puede conectarse a nivel de red.
resource "aws_security_group" "mongodb" {
  name        = "peliculas-mongodb-sg"
  description = "SG de MongoDB — solo accesible desde API y Worker"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id, aws_security_group.worker.id]
    description     = "MongoDB desde API y Worker"
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH admin"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "peliculas-mongodb-sg" }
}

# ── RabbitMQ: solo desde API y Worker ────────────────────────────────────────
# Puerto 5672: protocolo AMQP (pika)
# Puerto 15672: UI de management (opcional, solo para debug — abrir con cuidado)
resource "aws_security_group" "rabbitmq" {
  name        = "peliculas-rabbitmq-sg"
  description = "SG de RabbitMQ — AMQP desde API y Worker"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5672
    to_port         = 5672
    protocol        = "tcp"
    security_groups = [aws_security_group.api.id, aws_security_group.worker.id]
    description     = "AMQP desde API y Worker"
  }

  # Descomenta si necesitas acceder a la UI de management de RabbitMQ
  # ingress {
  #   from_port   = 15672
  #   to_port     = 15672
  #   protocol    = "tcp"
  #   cidr_blocks = ["TU_IP/32"]
  #   description = "RabbitMQ Management UI - solo tu IP"
  # }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH admin"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "peliculas-rabbitmq-sg" }
}

# ── Worker: solo SSH de entrada; sale hacia MongoDB y RabbitMQ ───────────────
resource "aws_security_group" "worker" {
  name        = "peliculas-worker-sg"
  description = "SG del Worker — solo SSH de entrada, accede a Mongo y Rabbit"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH admin"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "peliculas-worker-sg" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────
output "alb_sg_id"      { value = aws_security_group.alb.id }
output "api_sg_id"      { value = aws_security_group.api.id }
output "mongodb_sg_id"  { value = aws_security_group.mongodb.id }
output "rabbitmq_sg_id" { value = aws_security_group.rabbitmq.id }
output "worker_sg_id"   { value = aws_security_group.worker.id }
