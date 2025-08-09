#!/bin/bash
sudo su

# Dependencias
yum update -y
yum install -y docker git amazon-efs-utils jq aws-cli

systemctl start docker
systemctl enable docker

# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Montar EFS 
export EFS_ID=fs-xxxxxxxx
mkdir -p /var/www/html
mount -t efs ${EFS_ID}:/ /var/www/html
echo "${EFS_ID}:/ /var/www/html efs defaults,_netdev 0 0" >> /etc/fstab

#Buscar secrets
SECRET_NAME=xxxx
REGION=us-east-2

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --region $REGION \
  --query SecretString \
  --output text)

export DB_NAME=$(echo $SECRET_JSON | jq -r .DB_NAME)
export DB_USER=$(echo $SECRET_JSON | jq -r .DB_USER)
export DB_PASSWORD=$(echo $SECRET_JSON | jq -r .DB_PASSWORD)
export DB_HOST=$(echo $SECRET_JSON | jq -r .DB_HOST)

# Arquivos docker
mkdir -p /opt/wordpress-docker
cd /opt/wordpress-docker

cat > docker-compose.yml <<EOF
version: '3.1'

services:
  wordpress:
    image: wordpress
    restart: always
    ports:
      - "80:80"
    environment:
      WORDPRESS_DB_HOST: ${DB_HOST}
      WORDPRESS_DB_USER: ${DB_USER}
      WORDPRESS_DB_PASSWORD: ${DB_PASSWORD}
      WORDPRESS_DB_NAME: ${DB_NAME}
    volumes:
      - /var/www/html:/var/www/html
EOF

# Iniciar container
docker-compose up -d

