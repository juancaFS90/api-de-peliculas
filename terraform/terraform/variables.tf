variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para API y Worker"
  type        = string
  default     = "t3.micro"
}

variable "instance_type_db" {
  description = "Tipo de instancia EC2 para MongoDB (necesita más memoria)"
  type        = string
  default     = "t3.small"
}

variable "instance_type_broker" {
  description = "Tipo de instancia EC2 para RabbitMQ"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nombre del key pair de AWS para acceder por SSH"
  type        = string
  # Sin default: obligatorio. Crear con: aws ec2 create-key-pair --key-name peliculas-key
}

variable "project_tag" {
  description = "Tag de proyecto para identificar todos los recursos en AWS"
  type        = string
  default     = "peliculas-api"
}

variable "mongo_password" {
  description = "Contraseña del usuario admin de MongoDB"
  type        = string
  sensitive   = true
  default     = "password123"
  # IMPORTANTE: en producción pasar via: tofu apply -var='mongo_password=TuPasswordSegura'
  # o con un archivo terraform.tfvars (no commitear al repo)
}

variable "mongo_db_name" {
  description = "Nombre de la base de datos MongoDB"
  type        = string
  default     = "cartelera"
}

variable "rabbitmq_queue" {
  description = "Nombre del queue de RabbitMQ"
  type        = string
  default     = "peliculas"
}

variable "github_repo" {
  description = "URL del repositorio GitHub del proyecto (para clonar en EC2)"
  type        = string
  # Ejemplo: "https://github.com/tu-usuario/API-consultar_pelicula.git"
  # Sin default: obligatorio. Cambiar por tu URL real.
}
