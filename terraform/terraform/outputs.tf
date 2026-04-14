output "alb_dns_name" {
  description = "DNS del Load Balancer — usa esta URL para acceder a la API"
  value       = module.alb.dns_name
}

output "api_url" {
  description = "URL base de la API de películas"
  value       = "http://${module.alb.dns_name}"
}

output "health_check_url" {
  description = "Endpoint de health check del ALB"
  value       = "http://${module.alb.dns_name}/health"
}

output "api_1_public_ip" {
  description = "IP pública de la instancia API 1 (para SSH de debug)"
  value       = module.ec2_api_1.public_ip
}

output "api_2_public_ip" {
  description = "IP pública de la instancia API 2 (para SSH de debug)"
  value       = module.ec2_api_2.public_ip
}

output "worker_public_ip" {
  description = "IP pública del Worker (para SSH de debug)"
  value       = module.ec2_worker.public_ip
}

output "mongodb_private_ip" {
  description = "IP privada de MongoDB (solo accesible desde la VPC)"
  value       = module.ec2_mongodb.private_ip
}

output "rabbitmq_private_ip" {
  description = "IP privada de RabbitMQ (solo accesible desde la VPC)"
  value       = module.ec2_rabbitmq.private_ip
}

output "ssh_api_1" {
  description = "Comando SSH para conectarse a API 1"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2_api_1.public_ip}"
}

output "ssh_worker" {
  description = "Comando SSH para conectarse al Worker"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${module.ec2_worker.public_ip}"
}
