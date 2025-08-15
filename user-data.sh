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
mkdir -p /var/www/html
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFS_ID}.efs.us-east-2.amazonaws.com:/ /var/www/html 

#Buscar secrets
SECRET_NAME=xxxx
REGION=us-east-2

SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id $SECRET_NAME \
  --region $REGION \
  --query SecretString \
  --output text)

export DB_NAME="INSIRA_NOME_AQUI"
export DB_USER=$(echo $SECRET_JSON | jq -r .DB_USER)
export DB_PASSWORD=$(echo $SECRET_JSON | jq -r .DB_PASSWORD)
export DB_HOST="INSIRA_HOST_AQUI"

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

