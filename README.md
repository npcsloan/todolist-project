# Project-two

## About
The following explains the steps taken to deploy a Django application titled 'Todo-list' on two nodes (servers); for setting up the configuration of each file (Terraform configs, Ansible playbooks, etc.) please see https://github.com/npcsloan/project-two/tree/main. The tools used are as follows: Terraform for deploying required AWS resources, Ansible for updating and configuring target nodes from master node, Nginx for port forwarding and load balancing, Gunicorn for processing the requests from Nginx and sending them to the app servers and vice versa, Postgresql database for application data storage.

## Steps to initialize servers via Terraform
#### 1. Create terraform directory and initialize terraform
```
mkdir project-two
terraform init
```
#### 2. Create and configure configuration file for aws resources
```
code main.tf
#configure
```
https://github.com/npcsloan/todolist-project/blob/main/aws-tf/main.tf

#### 3. Create and configure file to specify provider
```
code providers.tf
#configure
```
https://github.com/npcsloan/todolist-project/blob/main/aws-tf/providers.tf

#### 4. Create and configure file containing variables
```
code variables.tf
#configure
```
https://github.com/npcsloan/todolist-project/blob/main/aws-tf/variables.tf

#### 5. Confirm that aws resources are configured as intended and then apply
```
terraform plan
terraform apply
```

## Steps taken in master node

#### 1. Input database information into env file
```
echo 'DB_NAME=todolist
DB_USER=postgres
DB_PASSWORD=<password>
DB_HOST=<database>
DB_PORT=5432
SECRET_KEY=<secretkey>' > env
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/env
#### 2. Input pem key and set permissions
```
echo '<mykey>' > mykey.pem
chmod 400 ~/mykey.pem
```
#### 3. Install ansible on master node
```
sudo yum update -y
sudo amazon-linux-extras install ansible2 -y
```
#### 4. Input details for target nodes, add variables
```
code inventory.ini
#configure
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/inventory.ini
#### 5. Create and run playbook to run initial updates on target nodes
```
code updates.yml
#configure
ansible-playbook updates.yml -i inventory.ini
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/updates.yml
#### 6. Create and run playbook to git clone files for todolist, install python3.10-venv, create venv, and install items from requirements.txt
```
code mypackages.yml
#configure
ansible-playbook mypackages.yml -i inventory.ini
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/mypackages.yml
#### 7. Create and run playbook to copy env file to target nodes
```
code copyenv.yml
#configure
ansible-playbook copyenv.yml -i inventory.ini
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/copyenv.yml
#### 8. Configure .service file for gunicorn
```
echo '
[Unit]
Description=Gunicorn instance to serve todolist

Wants=network.target
After=syslog.target network-online.target

[Service]
Type=simple
WorkingDirectory=/home/ubuntu/todo-list
ExecStart=/home/ubuntu/todo-list/venv/bin/gunicorn -c /home/ubuntu/todo-list/gunicorn_config.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target' > todolist.service
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/todolist.service
#### 9. Create and run playbook to copy todolist.service file to target nodes, enable and start gunicorn, and restart gunicorn when changes are made
```
code gunicorn.yml
#configure
ansible-playbook gunicorn.yml -i inventory.ini
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/gunicorn.yml
#### 10. Create a listener on port 80 that redirects traffic to port 9876
```
echo '
server {
    listen 80;

    server_name public_ip;

    location / {
        proxy_pass http://localhost:9876;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}' > todolist
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/todolist
#### 11. Create and run playbook that copies port forwarding config file (todolist) to target nodes, install nginx, change public ip in nginx config, and enable nginx site
```
code nginx.yml
#configure
ansible-playbook nginx.yml -i inventory.ini
```
https://github.com/npcsloan/todolist-project/blob/main/master-node/nginx.yml

## Architecture Diagram
![project-two-diagram](https://github.com/npcsloan/todolist-project/assets/123162008/4fcc4831-8d91-40a6-82f1-972df3b56886)
