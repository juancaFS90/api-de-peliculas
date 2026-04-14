variable "name" {
  type        = string
  description = "Nombre de la instancia EC2"
}

variable "instance_type" {
  type        = string
  description = "Tipo de instancia EC2 (t3.micro, t3.small, etc.)"
}

variable "key_name" {
  type        = string
  description = "Nombre del key pair para SSH"
}

variable "security_group_id" {
  type        = string
  description = "ID del Security Group asignado a la instancia"
}

variable "user_data" {
  type        = string
  default     = ""
  description = "Script bash de inicialización (cloud-init)"
}

variable "project_tag" {
  type        = string
  default     = "peliculas-api"
  description = "Tag de proyecto para identificación en AWS"
}
