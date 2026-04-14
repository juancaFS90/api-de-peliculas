#!/bin/bash
# install_worker.sh — Despliega el Worker de películas en EC2
# Variables inyectadas por templatefile() desde main.tf:
#   ${mongo_uri_param}, ${rabbitmq_url_param}, ${aws_region},
#   ${mongo_db}, ${rabbitmq_queue}, ${github_repo}

set -e
exec > /var/log/install_worker.log 2>&1

echo "=== [$(date)] Iniciando instalación del Worker ==="

# ── 1. Dependencias ───────────────────────────────────────────────────────────
apt-get update -y
apt-get install -y python3-pip python3-venv awscli git

# ── 2. Obtener credenciales desde SSM ────────────────────────────────────────
AWS_REGION="${aws_region}"

MONGO_URI=$(aws ssm get-parameter \
  --name "${mongo_uri_param}" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

RABBITMQ_URL=$(aws ssm get-parameter \
  --name "${rabbitmq_url_param}" \
  --with-decryption \
  --region "$AWS_REGION" \
  --query "Parameter.Value" \
  --output text)

echo "Parámetros obtenidos desde SSM."

# ── 3. Parsear URIs ───────────────────────────────────────────────────────────
MONGO_USER=$(echo "$MONGO_URI"     | sed -E 's|mongodb://([^:]+):.*|\1|')
MONGO_PASSWORD=$(echo "$MONGO_URI" | sed -E 's|mongodb://[^:]+:([^@]+)@.*|\1|')
MONGO_HOST=$(echo "$MONGO_URI"     | sed -E 's|.*@([^:/]+).*|\1|')
MONGO_PORT=$(echo "$MONGO_URI"     | sed -E 's|.*@[^:]+:([0-9]+).*|\1|')

RABBITMQ_HOST=$(echo "$RABBITMQ_URL" | sed -E 's|.*@([^:]+):.*|\1|')
RABBITMQ_PORT=$(echo "$RABBITMQ_URL" | sed -E 's|.*:([0-9]+)/.*|\1|')

# ── 4. Clonar repositorio ─────────────────────────────────────────────────────
cd /home/ubuntu
if [ -d "app" ]; then
  cd app && git pull
else
  git clone "${github_repo}" app
  cd app
fi

# ── 5. Entorno virtual ────────────────────────────────────────────────────────
python3 -m venv venv
source venv/bin/activate
pip install -r app/requirements.txt

# ── 6. Archivo .env ───────────────────────────────────────────────────────────
# El worker usa las mismas variables de entorno que la API.
# MONGO_PASSWOR (sin D): typo intencional heredado del código fuente.
cat > /home/ubuntu/app/.env <<EOF
MONGO_USER=$MONGO_USER
MONGO_PASSWOR=$MONGO_PASSWORD
MONGO_HOST=$MONGO_HOST
MONGO_PORT=$MONGO_PORT
MONGO_DB=${mongo_db}
MONGO_AUTH_SOURCE=admin
RABBITMQ_HOST=$RABBITMQ_HOST
RABBITMQ_PORT=$RABBITMQ_PORT
RABBITMQ_QUEUE=${rabbitmq_queue}
RABBITMQ_USER=guest
RABBITMQ_PASSWOR=guest
EOF

chown ubuntu:ubuntu /home/ubuntu/app/.env
chmod 600 /home/ubuntu/app/.env

# ── 7. Servicio systemd para el worker ───────────────────────────────────────
# El worker.py hace connect_to_rabbit() con retry cada 5s,
# por lo que puede arrancar antes que RabbitMQ esté listo.
cat > /etc/systemd/system/peliculas-worker.service <<EOF
[Unit]
Description=Worker de Películas (RabbitMQ consumer)
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/app/app
EnvironmentFile=/home/ubuntu/app/.env
ExecStart=/home/ubuntu/app/venv/bin/python -u -m worker.worker
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable peliculas-worker
systemctl start peliculas-worker

echo "=== [$(date)] Worker de Películas instalado y corriendo ==="
