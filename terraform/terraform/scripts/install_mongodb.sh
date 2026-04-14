#!/bin/bash
# install_mongodb.sh — Instala y configura MongoDB 7 en EC2 Ubuntu 22.04
# Corre como cloud-init (root) en el primer boot.

set -e
exec > /var/log/install_mongodb.log 2>&1

echo "=== [$(date)] Iniciando instalación de MongoDB ==="

apt-get update -y
apt-get install -y gnupg curl

# ── Repositorio oficial de MongoDB 7 ─────────────────────────────────────────
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
  https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
  tee /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update -y
apt-get install -y mongodb-org

# ── Configurar MongoDB ────────────────────────────────────────────────────────
# bindIp: 0.0.0.0 permite conexiones desde la red privada de la VPC.
# El Security Group es quien restringe el acceso real (solo API y Worker).
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

systemctl enable mongod
systemctl start mongod

# Esperar a que MongoDB arranque
sleep 5

# ── Crear usuario admin ───────────────────────────────────────────────────────
# El usuario y contraseña deben coincidir con los parámetros SSM.
# Por seguridad la contraseña se lee desde el archivo de variables de Terraform.
# En este script se usa la misma contraseña que se configuró en el SSM.
mongosh --eval "
  db = db.getSiblingDB('admin');
  db.createUser({
    user: 'admin',
    pwd: '${mongo_password}',
    roles: [ { role: 'root', db: 'admin' } ]
  });
" || echo "Usuario admin ya existe o MongoDB aún iniciando"

# ── Habilitar autenticación ───────────────────────────────────────────────────
cat >> /etc/mongod.conf <<EOF

security:
  authorization: enabled
EOF

systemctl restart mongod

echo "=== [$(date)] MongoDB instalado, autenticación habilitada ==="
