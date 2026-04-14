#!/bin/bash
# install_rabbitmq.sh — Instala y configura RabbitMQ en EC2 Ubuntu 22.04
# Corre como cloud-init (root) en el primer boot.

set -e
exec > /var/log/install_rabbitmq.log 2>&1

echo "=== [$(date)] Iniciando instalación de RabbitMQ ==="

apt-get update -y
apt-get install -y curl gnupg apt-transport-https

# ── Repositorios oficiales de Erlang y RabbitMQ ───────────────────────────────
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-erlang/setup.deb.sh' | bash
curl -1sLf 'https://dl.cloudsmith.io/public/rabbitmq/rabbitmq-server/setup.deb.sh' | bash

apt-get update -y
apt-get install -y erlang rabbitmq-server

systemctl enable rabbitmq-server
systemctl start rabbitmq-server

# ── Plugin de management (UI web en puerto 15672) ─────────────────────────────
# Útil para debug. El Security Group bloquea el acceso por defecto;
# abre el puerto 15672 manualmente si lo necesitas.
rabbitmq-plugins enable rabbitmq_management

# ── Esperar a que RabbitMQ arranque completamente ────────────────────────────
sleep 10

# ── Crear queue 'peliculas' para que exista antes de que la API arranque ─────
# El código en publisher.py y worker.py llaman queue_declare (idempotente),
# pero tenerlo pre-creado evita race conditions.
rabbitmqctl await_startup
rabbitmqadmin declare queue name=peliculas durable=true || \
  echo "Queue peliculas no se pudo crear via rabbitmqadmin, el código la creará al conectar"

echo "=== [$(date)] RabbitMQ instalado y corriendo ==="
