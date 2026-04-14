terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6.0"
}

provider "aws" {
  region = var.aws_region
}

# ── VPC por defecto ───────────────────────────────────────────────────────────
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ── Security Groups ───────────────────────────────────────────────────────────
module "sg" {
  source = "./modules/sg"
  vpc_id = data.aws_vpc.default.id
}

# ── EC2: MongoDB ──────────────────────────────────────────────────────────────
# DECISIÓN ARQUITECTURAL: MongoDB en EC2 (no DocumentDB) porque el código usa
# pymongo directamente y el driver es 100% compatible. Para producción real
# se recomienda migrar a MongoDB Atlas o DocumentDB.
module "ec2_mongodb" {
  source            = "./modules/ec2"
  name              = "peliculas-mongodb"
  instance_type     = var.instance_type_db   # t3.small mínimo para MongoDB
  key_name          = var.key_name
  security_group_id = module.sg.mongodb_sg_id
  project_tag       = var.project_tag
  # templatefile en lugar de file() para inyectar mongo_password dinámicamente.
  # Esto garantiza que la password en MongoDB siempre coincida con la del SSM.
  user_data = templatefile("${path.module}/scripts/install_mongodb.sh", {
    mongo_password = var.mongo_password
  })
}

# ── EC2: RabbitMQ ─────────────────────────────────────────────────────────────
# DECISIÓN ARQUITECTURAL: RabbitMQ en EC2 (no Amazon MQ) para mantener
# el mismo driver pika sin cambios en el código. Para producción se
# recomienda Amazon MQ for RabbitMQ.
module "ec2_rabbitmq" {
  source            = "./modules/ec2"
  name              = "peliculas-rabbitmq"
  instance_type     = var.instance_type_broker
  key_name          = var.key_name
  security_group_id = module.sg.rabbitmq_sg_id
  project_tag       = var.project_tag
  user_data         = file("${path.module}/scripts/install_rabbitmq.sh")
}

# ── Parameter Store: credenciales y conexiones ───────────────────────────────
# Los parámetros usan las IPs privadas de las EC2 para comunicación interna.
# MONGO_PASSWOR (typo intencional): el código fuente lee esta variable con ese
# nombre exacto (db.py y docker-compose.yml).
resource "aws_ssm_parameter" "mongo_uri" {
  name  = "/${var.project_tag}/mongo_uri"
  type  = "SecureString"
  value = "mongodb://admin:${var.mongo_password}@${module.ec2_mongodb.private_ip}:27017/?authSource=admin"
}

resource "aws_ssm_parameter" "rabbitmq_url" {
  name  = "/${var.project_tag}/rabbitmq_url"
  type  = "SecureString"
  value = "amqp://guest:guest@${module.ec2_rabbitmq.private_ip}:5672/"
}

# ── EC2: API x2 (detrás del ALB) ─────────────────────────────────────────────
# Dos instancias replicando el setup de docker-compose (api1 + api2 + haproxy)
# pero con el ALB de AWS reemplazando a HAProxy.
module "ec2_api_1" {
  source            = "./modules/ec2"
  name              = "peliculas-api-1"
  instance_type     = var.instance_type
  key_name          = var.key_name
  security_group_id = module.sg.api_sg_id
  project_tag       = var.project_tag
  user_data = templatefile("${path.module}/scripts/install_api.sh", {
    mongo_uri_param    = aws_ssm_parameter.mongo_uri.name
    rabbitmq_url_param = aws_ssm_parameter.rabbitmq_url.name
    aws_region         = var.aws_region
    instance_name      = "api1"
    mongo_db           = var.mongo_db_name
    rabbitmq_queue     = var.rabbitmq_queue
    github_repo        = var.github_repo
  })
}

module "ec2_api_2" {
  source            = "./modules/ec2"
  name              = "peliculas-api-2"
  instance_type     = var.instance_type
  key_name          = var.key_name
  security_group_id = module.sg.api_sg_id
  project_tag       = var.project_tag
  user_data = templatefile("${path.module}/scripts/install_api.sh", {
    mongo_uri_param    = aws_ssm_parameter.mongo_uri.name
    rabbitmq_url_param = aws_ssm_parameter.rabbitmq_url.name
    aws_region         = var.aws_region
    instance_name      = "api2"
    mongo_db           = var.mongo_db_name
    rabbitmq_queue     = var.rabbitmq_queue
    github_repo        = var.github_repo
  })
}

# ── EC2: Worker ───────────────────────────────────────────────────────────────
module "ec2_worker" {
  source            = "./modules/ec2"
  name              = "peliculas-worker"
  instance_type     = var.instance_type
  key_name          = var.key_name
  security_group_id = module.sg.worker_sg_id
  project_tag       = var.project_tag
  user_data = templatefile("${path.module}/scripts/install_worker.sh", {
    mongo_uri_param    = aws_ssm_parameter.mongo_uri.name
    rabbitmq_url_param = aws_ssm_parameter.rabbitmq_url.name
    aws_region         = var.aws_region
    mongo_db           = var.mongo_db_name
    rabbitmq_queue     = var.rabbitmq_queue
    github_repo        = var.github_repo
  })
}

# ── Application Load Balancer ─────────────────────────────────────────────────
# Reemplaza al haproxy-master y haproxy-backup del docker-compose.
# El ALB de AWS ya tiene alta disponibilidad nativa.
module "alb" {
  source     = "./modules/alb"
  name       = "peliculas-alb"
  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids
  sg_id      = module.sg.alb_sg_id
  project_tag = var.project_tag
  api_instance_ids = [
    module.ec2_api_1.instance_id,
    module.ec2_api_2.instance_id,
  ]
}
