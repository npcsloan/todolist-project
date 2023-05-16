# Project-two

## About
The following explains the steps taken to deploy a Django application titled 'Todo-list' on two nodes (servers); for setting up the configuration of each file (Terraform configs, Ansible playbooks, etc.) please see https://github.com/npcsloan/project-two/tree/main. The tools used are as follows: Terraform for deploying required AWS resources, Ansible for updating and configuring target nodes from master node, Nginx for port forwarding and load balancing, Gunicorn for processing the requests from Nginx and sending them to the app servers and vice versa, Postgresql database for application data storage.

## Initialize servers via Terraform
```
mkdir project-two
terraform init

code main.tf
#configure

code providers.tf
#configure

code variables.tf
#configure

terraform plan
terraform apply
```

## Commands in master node

#### Input database information into env file
```
echo '
DB_NAME=todolist
DB_USER=postgres
DB_PASSWORD=<pwd>
DB_HOST=<database>
DB_PORT=5432
SECRET_KEY=<secretkey>' > env
```
#### Input pem key and set permissions
```
echo '<mykey>' > mykey.pem
chmod 400 ~/mykey.pem
```
#### Install ansible on master node
```
sudo yum update -y
sudo amazon-linux-extras install ansible2 -y
```
#### Input details for target nodes, add variables
```
code inventory.ini
#configure
```
#### Create and run playbook to run initial updates on target nodes
```
code updates.yml
#configure
ansible-playbook updates.yml -i inventory.ini
```
#### Create and run playbook to git clone files for todolist, install python3.10-venv, create venv, and install items from requirements.txt
```
code mypackages.yml
#configure
ansible-playbook mypackages.yml -i inventory.ini
```
#### Create and run playbook to copy env file to target nodes
```
code copyenv.yml
#configure
ansible-playbook copyenv.yml -i inventory.ini
```
#### Configure .service file for gunicorn
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
#### Create and run playbook to copy todolist.service file to target nodes, enable and start gunicorn, and restart gunicorn when changes are made
```
code gunicorn.yml
#configure
ansible-playbook gunicorn.yml -i inventory.ini
```
#### Create a listener on port 80 that redirects traffic to port 9876
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
#### Create and run playbook that copies port forwarding config file (todolist) to target nodes, install nginx, change public ip in nginx config, and enable nginx site
```
code nginx.yml
#configure
ansible-playbook nginx.yml -i inventory.ini
```

## Architecture Diagram
![project-two-diagram](https://github.com/npcsloan/project-two/assets/123162008/d55090e3-1751-46c6-be1a-0e5aa4c59002)




