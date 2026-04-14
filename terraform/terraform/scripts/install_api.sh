#!/bin/bash
# install_api.sh — Despliega la API Flask de películas en EC2
# Este script corre como cloud-init (root) en el primer boot.
# Variables inyectadas por templatefile() desde main.tf:
#   ${mongo_uri_param}, ${rabbitmq_url_param}, ${aws_region},
#   ${instance_name}, ${mongo_db}, ${rabbitmq_queue}, ${github_repo}

set -e
exec > /var/log/install_api.log 2>&1

echo "=== [$(date)] Iniciando instalación de API de Películas ==="

# ── 1. Actualizar sistema e instalar dependencias ─────────────────────────────
apt-get update -y
apt-get install -y python3-pip python3-venv awscli git

# ── 2. Obtener credenciales desde AWS SSM Parameter Store ────────────────────
AWS_REGION="${aws_region}"
MONGO_URI_PARAM="${mongo_uri_param}"
RABBITMQ_URL_PARAM="${rabbitmq_url_param}"

echo "Leyendo parámetros desde SSM..."

MONGO_URI=$(aws ssm get-parameter \
  --name "$MONGO_URI_PARAM" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

RABBITMQ_URL=$(aws ssm get-parameter \
  --name "$RABBITMQ_URL_PARAM" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

echo "Parámetros obtenidos correctamente."

# ── 3. Parsear componentes de las URIs ───────────────────────────────────────
# Parsea: mongodb://admin:password@IP:27017/?authSource=admin
MONGO_USER=$(echo "$MONGO_URI"     | sed -E 's|mongodb://([^:]+):.*|\1|')
MONGO_PASSWORD=$(echo "$MONGO_URI" | sed -E 's|mongodb://[^:]+:([^@]+)@.*|\1|')
MONGO_HOST=$(echo "$MONGO_URI"     | sed -E 's|.*@([^:/]+).*|\1|')
MONGO_PORT=$(echo "$MONGO_URI"     | sed -E 's|.*@[^:]+:([0-9]+).*|\1|')

# Parsea: amqp://guest:guest@IP:5672/
RABBITMQ_HOST=$(echo "$RABBITMQ_URL" | sed -E 's|.*@([^:]+):.*|\1|')
RABBITMQ_PORT=$(echo "$RABBITMQ_URL" | sed -E 's|.*:([0-9]+)/.*|\1|')

echo "MongoDB host: $MONGO_HOST | RabbitMQ host: $RABBITMQ_HOST"

# ── 4. Clonar el repositorio ──────────────────────────────────────────────────
cd /home/ubuntu
if [ -d "app" ]; then
  echo "Directorio app ya existe, actualizando..."
  cd app && git pull
else
  git clone "${github_repo}" app
  cd app
fi

# ── 5. Crear entorno virtual e instalar dependencias ─────────────────────────
python3 -m venv venv
source venv/bin/activate
pip install -r app/requirements.txt

# ── 6. Crear archivo .env con las variables que espera el código ──────────────
# IMPORTANTE: el código usa MONGO_PASSWOR (sin D final) — typo en db.py y
# docker-compose.yml. Se respeta aquí para no modificar el código fuente.
cat > /home/ubuntu/app/.env <<EOF
INSTANCE_NAME=${instance_name}
MONGO_USER=$MONGO_USER
MONGO_PASSWOR=$MONGO_PASSWORD
MONGO_HOST=$MONGO_HOST
MONGO_PORT=$MONGO_PORT
MONGO_DB=${mongo_db}
MONGO_AUTH_SOURCE=admin
RABBITMQ_HOST=$RABBITMQ_HOST
RABBITMQ_PORT=$RABBITMQ_PORT
RABBITMQ_QUEUE=${rabbitmq_queue}
EOF

chown ubuntu:ubuntu /home/ubuntu/app/.env
chmod 600 /home/ubuntu/app/.env

# ── 7. Crear servicio systemd para la API Flask ───────────────────────────────
cat > /etc/systemd/system/peliculas-api.service <<EOF
[Unit]
Description=API de Películas (Flask)
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app/app
EnvironmentFile=/home/ubuntu/app/.env
ExecStart=/home/ubuntu/app/venv/bin/python main.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable peliculas-api
systemctl start peliculas-api

echo "=== [$(date)] API de Películas instalada y corriendo en el puerto 5000 ==="
