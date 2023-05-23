# Project-two

## About
The following explains the steps taken to deploy a Django application titled 'Todo-list' on two nodes (servers). The tools used are as follows: Terraform for deploying required AWS resources, Ansible for updating and configuring target nodes from master node, Nginx for port forwarding and load balancing, Gunicorn for processing the requests from Nginx and sending them to the app servers and vice versa, Postgresql database for application data storage.

## Architecture Diagram
![project-two-diagram](https://github.com/npcsloan/todolist-project/assets/123162008/4fcc4831-8d91-40a6-82f1-972df3b56886)

## Steps to initialize servers via Terraform
#### 1. Create terraform directory and initialize terraform
```
mkdir project-two
terraform init
```

#### 2. Create and configure configuration file for aws resources
```
echo '
# set region
provider "aws" {
  region = "us-west-1"
}

# create vpc
resource "aws_vpc" "myvpc" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_hostnames = true
  tags = {
    Name = "project-two"
  }
}

# create internet gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id
}

# create route table
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }
}

# create public subnet1
resource "aws_subnet" "pub_sub1" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.0.0/28"
  availability_zone = "us-west-1a"
  tags = {
    Name = "public1"
  }
}

# create public subnet2
resource "aws_subnet" "pub_sub2" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.0.16/28"
  availability_zone = "us-west-1c"
  tags = {
    Name = "public2"
  }
}

# associate subnet1 with route table
resource "aws_route_table_association" "igw_rta1" {
  subnet_id      = aws_subnet.pub_sub1.id
  route_table_id = aws_route_table.pub_rt.id
}

# associate subnet2 with route table
resource "aws_route_table_association" "igw_rta2" {
  subnet_id      = aws_subnet.pub_sub2.id
  route_table_id = aws_route_table.pub_rt.id
}

# create security group
resource "aws_security_group" "mysg" {
  name   = "http-ssh"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create master node
resource "aws_instance" "master" {
  key_name                    = "study-key"
  ami                         = "ami-087bf433bedbc2ef7"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.mysg.id]
  subnet_id                   = aws_subnet.pub_sub1.id
  associate_public_ip_address = true
  tags = {
    Name = "master"
  }
}
# Need to go back and put one target node on pub_sub1
# Create target nodes
resource "aws_instance" "node1" {
  key_name                    = "study-key"
  ami                         = "ami-0f8e81a3da6e2510a"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.mysg.id]
  subnet_id                   = aws_subnet.pub_sub1.id
  associate_public_ip_address = true
  tags = {
    Name = "node1"
  }
}

resource "aws_instance" "node2" {
  key_name                    = "study-key"
  ami                         = "ami-0f8e81a3da6e2510a"
  instance_type               = "t2.micro"
  vpc_security_group_ids      = [aws_security_group.mysg.id]
  subnet_id                   = aws_subnet.pub_sub2.id
  associate_public_ip_address = true
  tags = {
    Name = "node2"
  }
}' > main.tf
```

#### 3. Create and configure file to specify provider
```
code providers.tf
#configure
echo '
# set provider as aws
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
}' > providers.tf
```

#### 4. Confirm that aws resources are configured as intended and then apply
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
echo '
[webservers]
node1 ansible_host=<node1ip> ansible_user=ubuntu
node2 ansible_host=<node2ip> ansible_user=ubuntu

[all:vars]
ansible_ssh_private_key_file=<mykey.pem>
repo_url=https://github.com/chandradeoarya/
repo=todo-list
home_dir=/home/ubuntu
repo_dir={{ home_dir }}/{{ repo }}
django_project=to_do_proj

; [defaults]
; host_key_checking=no' > inventory.ini
```

#### 5. Ping target nodes to confirm connection
```
ansible node1 -m ping -i inventory.ini
ansible node2 -m ping -i inventory.ini
```

#### 6. Create and run playbook to run initial updates on target nodes
```
echo '
---
- hosts: all
  become: yes
  become_user: root
  gather_facts: no
  tasks:
    - name: Running system update
      apt: update_cache=yes
        upgrade=safe
      register: result
    - debug: var=result.stdout_lines' > updates.yml
ansible-playbook updates.yml -i inventory.ini
```

#### 7. Create and run playbook to git clone files for todolist, install python3.10-venv, create venv, and install items from requirements.txt
```
echo '
- hosts: all
  become: yes
  become_user: ubuntu
  gather_facts: no

  tasks:
    - name: pull branch master
      git:
        repo: "{{ repo_url }}/{{ repo }}.git"
        dest: "{{ repo_dir }}"
        accept_hostkey: yes

- hosts: all
  become: yes
  become_user: root
  gather_facts: no
  tasks:
    - name: install python3.10-venv
      apt:
        name: python3.10-venv
        state: present

- hosts: all
  gather_facts: no
  tasks:
    - name: Create virtual environment
      command: python3 -m venv venv
      args:
        chdir: "{{ repo_dir }}"

    - name: install python requirements
      pip:
        requirements: "{{ repo_dir }}/requirements.txt"
        state: present
        executable: "{{ repo_dir }}/venv/bin/pip"' > mypackages.yml
ansible-playbook mypackages.yml -i inventory.ini
```

#### 8. Create and run playbook to copy env file to target nodes
```
echo '
---
- name: Set environment variables on hosts
  hosts: all
  become: true
  become_user: ubuntu
  tasks:
    - name: Copy env file to hosts
      copy:
        src: env
        dest: /home/ubuntu/todo-list/.env
        mode: 0644' > copyenv.yml
ansible-playbook copyenv.yml -i inventory.ini
```

#### 9. Configure .service file for gunicorn
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

#### 10. Create and run playbook to copy todolist.service file to target nodes, enable and start gunicorn, and restart gunicorn when changes are made
```
echo '
---
- hosts: all
  become: yes
  become_user: root
  gather_facts: no
  tasks:
    - name: Copy Gunicorn systemd service file
      template:
        src: todolist.service
        dest: /etc/systemd/system/todolist.service
      register: gunicorn_service

    - name: Enable and start Gunicorn service
      systemd:
        name: todolist
        state: started
        enabled: yes
      when: gunicorn_service.changed
      notify:
        - Restart Gunicorn

    - name: Restart Gunicorn
      systemd:
        name: todolist
        state: restarted
      when: gunicorn_service.changed

  handlers:
    - name: Restart Gunicorn
      systemd:
        name: todolist
        state: restarted' > gunicorn.yml
ansible-playbook gunicorn.yml -i inventory.ini
```

#### 11. Create a listener on port 80 that redirects traffic to port 9876
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

#### 12. Create and run playbook that copies port forwarding config file (todolist) to target nodes, install nginx, change public ip in nginx config, and enable nginx site
```
echo '
---
- name: Configure Nginx port forwarding
  hosts: all
  become: true
  become_user: root
  gather_facts: no
  tasks:
    - name: Install Nginx
      apt:
        name: nginx
        state: present

    - name: Configure Nginx
      template:
        src: todolist
        dest: /etc/nginx/sites-available/todolist
        owner: root
        group: root
        mode: 0644
      notify: Restart Nginx

    - name: Change public_ip in Nginx configuration
      replace:
        path: /etc/nginx/sites-available/todolist
        regexp: 'server_name public_ip;'
        replace: 'server_name {{ ansible_host }};'

    - name: Enable Nginx site
      file:
        src: /etc/nginx/sites-available/todolist
        dest: /etc/nginx/sites-enabled/todolist
        state: link
      notify: Restart Nginx

  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted' > nginx.yml
ansible-playbook nginx.yml -i inventory.ini
```
