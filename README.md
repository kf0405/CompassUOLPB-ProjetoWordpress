# 📘 Projeto WordPress na AWS - Infraestrutura Escalável

Este projeto tem como objetivo implantar uma arquitetura escalável e de alta disponibilidade para o WordPress utilizando recursos da AWS como VPC, RDS, EFS, EC2 com Auto Scaling e Load Balancer.

---

## Recursos utilizados

Certifique-se de possuir acesso à todos os seguintes serviços utilizados:

| Serviço AWS     | Uso                            |
| --------------- | ------------------------------ |
| VPC             | Rede personalizada             |
| EC2             | Instâncias para WordPress      |
| RDS             | Banco de dados relacional      |
| EFS             | Armazenamento compartilhado    |
| ALB             | Load balancer de aplicação     |
| ASG             | Escalabilidade automática      |
| Secrets Manager | Armazenamento seguro de senhas |

---

## Versões do Projeto

### 🔹 **v1.0 - Criação da VPC, dos SGs e do RDS**

**Objetivo**: Criar a base de rede e o banco de dados

**Etapas:**

- Criação da VPC  
  Para criar a VPC, acessamos inicialmente a dashboard VPC, pesquisando pela VPC na página inicial da AWS. Ao clicar em VPC, veremos a seguinte página:
  ![Dashboard VPC](imgs/vpc1.png)
  A partir dela, clicamos em 'Criar VPC'. Na janela de criação, selecione o modo VPC and more, para criação automática da VPC com subnets e routing tables. Escolha o nome desejado e o bloco IPv4 desejado.
  ![Criar VPC](imgs/vpc2.png)
  Em seguida, selecione o número de Availability Zones desejadas para a VPC, assim como o número de redes privadas e públicas em cada uma. Para o projeto em questão, escolhemos 2 AZs, com 4 redes privadas e 2 redes públicas.
  ![Redes VPC](imgs/vpc3.png)
  Por fim, selecione o NAT Gateway, que será criado para que tenhamos acesso público às redes privadas. Lembrando que necessitaremos de um NAT Gateway para cada subnet pública para acessar as privadas ou apenas um só para todas as privadas, que será o caso escolhido nesse projeto. Em produção, seria interessante utilizar 2 NATs.
  ![NAT Gateway](imgs/vpc4.png)
  Resultado final:
  ![Resultado final da criação VPC](imgs/vpc6.png)

---

- Criação dos SGs  
  Para cada serviço que desejamos implementar, criaremos um security group separado, a fim de separar as funcionalidades desejadas a cada um. Entrando em security group, veremos a página de criação de security group. Nessa página, escolhemos um nome, descrição, à qual VPC pertence esse grupo, e definimos suas regras Inbound e Outbound.
  ![Security Group](imgs/sg1.png)
  ![Security Group](imgs/sg2.png)
  As regras que definiremos seguirão a seguinte forma:

### Tabela Security Groups

| Security Group | Direção  | Protocolo | Porta | Origem/Destino | Observação                         |
| -------------- | -------- | --------- | ----- | -------------- | ---------------------------------- |
| **ALB**        | Inbound  | TCP       | 80    | 0.0.0.0/0      | HTTP aberto para o público         |
|                | Inbound  | TCP       | 443   | 0.0.0.0/0      | HTTPS aberto para o público        |
|                | Outbound | All       | All   | 0.0.0.0/0      | Necessário para encaminhar tráfego |
| **EC2**        | Inbound  | TCP       | 80    | SG do ALB      | Recebe tráfego HTTP do ALB         |
|                | Inbound  | TCP       | 2049  | SG do EFS      | Comunicação com EFS (NFS)          |
|                | Outbound | TCP       | 3306  | SG do RDS      | Conecta ao banco MySQL/Aurora      |
|                | Outbound | TCP       | 2049  | SG do EFS      | Monta o EFS                        |
|                | Outbound | TCP       | 443   | 0.0.0.0/0      | Acessa serviços externos via HTTPS |
| **RDS**        | Inbound  | TCP       | 3306  | SG da EC2      | Somente EC2 pode acessar o banco   |
|                | Outbound | Nenhuma   | -     | -              | RDS não inicia conexões            |
| **EFS**        | Inbound  | TCP       | 2049  | SG da EC2      | Somente EC2 pode montar o EFS      |
|                | Outbound | Nenhuma   | -     | -              | Não é necessário outbound          |

---

![Resultado final](imgs/sg3.png)

---

- Criação do RDS  
  Para criar o RDS, pesquisaremos por "Aurora and RDS" na página inicial da AWS. Nessa página, como podemos ver abaixo, clicaremos em "Create Database"
  ![RDS Dashboard](imgs/rds1.png)
  No início da criação, escolheremos o modo de criação "Standard Create", onde podemos definir mais configurações, e selecionaremos como engine o "MySQL"
  ![Create Database](imgs/rds2.png)
  Em seguida definimos o nome do Banco de Dados, e as informações das credenciais. Essas informações são cruciais para gerenciar a segurança do seu banco de dados, então aja cautelosamente. No projeto em questão, usaremos o Secrets Manager, para evitar a exposição dos segredos no script do user-data.
  ![Secrets](imgs/rds3.png)
  Em templates, selecionamos "Free Tier" e em Availability, selecionamos "Single-AZ"
  ![Templates and Availability](imgs/rds4.png)
  Em configuração da instância, selecionaremos "db.t3.micro" ao invés do padrão "db.t4g.micro"
  ![Instância](imgs/rds6.png)
  Em conectividade, selecionamos para conectar com a instância, e escolhemos uma instância com a qual o banco se conectará. Caso ainda não tenha criado, pule essa parte usando o "Don't connect to an EC2 Compute Resource"
  ![Connectivity](imgs/rds7.png)
  Deixe aqui a configuração de subnet padrão e selecione "Choose Existing" para o SG. Utilizamos aqui o SG criado na etapa anterior.
  ![SG](imgs/rds8.png)
  Em seguida, selecione a Availability Zone do banco e o certificado.
  ![AZ](imgs/rds9.png)
  Por fim, selecionar as configurações de Monitoramento. Aqui podemos selecionar alguns logs que serão enviados para o CloudWatch.
  ![Logs](imgs/rds10.png)

---

### 🔹 **v1.1 - Configuração do EFS**

**Objetivo**: Criar o sistema de arquivos compartilhado entre instâncias
**Etapas:**

- Criar EFS  
  Para criar o EFS, pesquisaremos por EFS e selecionaremos "Create". Nessa janela, selecionamos nome, tipo, e AZ.
  ![Create](imgs/efs1.png)
  Em seguida, em configurações de performance, selecionamos Bursting, pois não necessitamos, para o projeto da performance balanceada do modo "Enhanced".
  ![Performance](imgs/efs3.png)
  Em "Lifecycle Management" podemos também retirar as opções de transição para outros tipos de armazenamento, para fins de projeto. Observamos que essas opções são muito interessantes para a preservação dos dados.
  ![Lifecycle Management](imgs/efs4.png)  
  Após a criação, entre em "View Details" do file system criado e clique em "Attach".
  ![Attach](imgs/efs6.png)  
  Com a opção "Mount via DNS" selecionada, copie o comando para montar pelo NFS, ele será utilizado posteriormente no script user-data, com a alteração para que montemos em /var/www/html. Um exemplo de comando pode ser visto abaixo.
  `sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFS_ID}.efs.us-east-2.amazonaws.com:/ /var/www/html`

---

### 🔹 **v1.2 - Deploy do WordPress com Docker e EFS**

**Objetivo**: Rodar o WordPress via Docker com volume montado no EFS

**Etapas:**

- Criar Launch Template com `user-data`  
  Para criação do Launch template, temos duas opções: criação do template manualmente ou criar uma instância e transformá-la no template. Para fim de projeto, executaremos as duas formas.
  - Criação EC2  
    Selecionar tags(as apropriadas do seu projeto, na imagem apenas um exemplo), imagem(usaremos Amazon Linux mais recente), par de chaves.  
    ![Create EC2](imgs/ec2temp1.png)
    Ao fim, em "Advanced Details", insira o script de user-data.  
    Criado o template, clicar com o botão direito e em "Images and Templates", selecionar "Create template from instance".
    ![Template from instance](imgs/template9.png)
  - Criação manual  
    Pesquisamos na página inicial AWS por Launch Template, e em seguida selecionamos "Create Template". Na página inicial, selecionamos um nome e uma descrição da versão do Template.
    ![Create Template](imgs/template1.png)
    Em seguida selecionamos a imagem base desse template, que no caso foi uma imagem Amazon Linux.
    ![Image](imgs/template2.png)
    O próximo são as tags, que podem ou não ser necessárias a depender do uso do seu projeto.
    ![Tags](imgs/template3.png)
    Em seguida selecionamos o par de chaves para autenticação SSH.
    ![Key Pair](imgs/template4.png)
    Em Network Settings, podemos selecionar um grupo existente, selecionando o grupo que criamos na versão 1.0. Selecionamos também a AZ onde desejamos colocar a instância.
    ![Network Settings](imgs/template5.png)
    Podemos permitir o monitoramento CloudWatch ou não, a depender do projeto.
    ![CloudWatch](imgs/template7.png)
    Ao fim inserimos o script do user-data.
    ![User Data](imgs/template8.png)

**Descrição do user-data**

- Primeiramente realizamos as instalações necessárias e inicializamos o docker. O sudo é utilizado para que os comandos docker funcionem.

```
#!/bin/bash
sudo su

# Dependencias
yum update -y
yum install -y docker git amazon-efs-utils jq aws-cli

systemctl start docker
systemctl enable docker
```

- Aqui instalamos o Docker Compose

```
# Instalar Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
```

- Aqui realizamos a montagem da EFS, utilizando seu ID. Lembre-se de substituir o seu ID em EFS_ID.

```
# Montar EFS  
mkdir -p /var/www/html
sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFS_ID}.efs.us-east-2.amazonaws.com:/ /var/www/html
```

- Agora buscaremos os segredos no Secrets Manager, para utilizarmos na inicialização do Banco de Dados. Coloque na variável SECRET-NAME o nome do seu secret.

```
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
```

- Criamos aqui o docker-compose selecionando os serviços desejados, e ao fim inicializamos.

```
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
```

---

### 🔹 **v1.3 - Criação do Auto Scaling Group (ASG) e Configuração do Application Load Balancer (ALB)**

**Objetivo**: Garantir alta disponibilidade com escalabilidade automática e distribuir o tráfego entre instâncias

**Etapas:**

- Na página inicial da AWS, buscamos por Auto Scaling Groups. Na página inicial, clicamos em "Create Auto Scaling Group". Em seguida, escolhemos nome e o "Launch Template" criado anteriormente como base. Selecione a versão correta de seu Launch Template.
  ![Create ASG](imgs/asg1.png)
- Selecionamos em seguida as opções de Rede, selecionando VPC, AZs, e Balanced Only. Lembrando que para o caso desse projeto, a subnet deverá ser uma private, e não public.
  ![Network](imgs/asg2.png)
- Na opção seguinte, podemos selecionar um Load Balancer já criado ou criar um para esse grupo. Selecionando "Attach to a new load balancer", temos a tela de criação do ALB.
  ![ALB](imgs/lb1.png)
- Aqui, selecionar "Application Load Balancer", um nome, se é externo ou interno, VPC, AZ e redes.
  ![Configurações LB](imgs/lb2.png)
- Ao fim, caso seja necessário, configure um listener em uma porta para acesso.
  ![Listener](imgs/lb3.png)
- Voltando ao ASG, temos as configurações de Health Checks
  ![Health Checks](imgs/asg3.png)
- E, para concluir, selecione o tamanho do grupo - sua capacidade desejada. Em "Scaling", selecione os limites inferior e superior da sua capacidade.
  ![Capacidade](imgs/asg4.png)

---

### v1.4 Criação do Bastion Host e Atividades extras

- Criaremos uma instância EC2, designada como Bastion Host, nas subnets públicas, para podermos nos conectar às instâncias em subnets privadas.
- Para fim de testes, basta criar uma instância, utilizar as tags desejadas, e se conectar a ela. Lembre-se de colocá-la na mesma VPC das outras, se não não conseguiremos conectar à elas.
- Lembrar também de adicionar ao SG das EC2 a regra de Inbound do SSH, para permitir a conexão do Bastion às mesmas.
- Para conectar às instâncias privadas usando o bastion host, podemos utilizar o comando abaixo:  
`ssh -J user@bastion_host user@target_host`
---

### Atividades extras

**Criando AMI**

- Para criar uma AMI, é necessário que exista uma instância criada. Selecione a instância e clique em "Actions" e em seguida "Images and Templates -> Create Image"
- Preencha o nome da imagem, sua descrição, marque como No reboot se desejar que ela não se reinicialize
- Encerre clicando "Create Image"
- Utilize tags para melhor configurar sua AMI.

**Monitoramento com CloudWatch**

- Pesquise por CloudWatch. Podemos adicionar alarmes para registrar erros como quedas do serviço. Clicamos em "Create Alarm".
- Em seguida clicamos em "Select Metric".
- Podemos aqui criar vários tipos de alarmes para registro no CloudWatch. Nesse caso, usaremos alarmes no Auto Scaling Group, para observar as alterações no número de instâncias.  

**Aumento do tráfego simulado para testar ASG**

- Para simular o aumento de tráfego, podemos usar o ApacheBench, que já é comum em várias distribuições Linux. Usamos com ele um comando da seguinte forma, a fim de aumentar a carga do servidor.
  `ab -n 1000 -c 50 http://<your-ec2-public-ip>/`
- Esse comando pode ser executado acessando a instância.  

---
