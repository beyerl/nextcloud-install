#!/bin/bash

echo "
 _______                   __         .__                   .___ .___                 __         .__  .__   
 \      \   ____ ___  ____/  |_  ____ |  |   ____  __ __  __| _/ |   | ____   _______/  |______  |  | |  |  
 /   |   \_/ __ \\  \/  /\   __\/ ___\|  |  /  _ \|  |  \/ __ |  |   |/    \ /  ___/\   __\__  \ |  | |  |  
/    |    \  ___/ >    <  |  | \  \___|  |_(  <_> )  |  / /_/ |  |   |   |  \\___ \  |  |  / __ \|  |_|  |__
\____|__  /\___  >__/\_ \ |__|  \___  >____/\____/|____/\____ |  |___|___|  /____  > |__| (____  /____/____/
        \/     \/      \/           \/                       \/           \/     \/            \/           

Installation script for Nextcloud on CentOS 7 using Docker

"

echo "updating CentOS"
yum update

echo "
=============== Docker ===============
"                                

echo "downloading docker ce..."
wget https://download.docker.com/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker.repo

echo "installing docker ce..."
yum install docker-ce –y

echo "starting docker..."
systemctl start docker
systemctl enable docker

echo "installing docker compose..."
yum install epel-release
yum install python-pip
pip install docker-compose
docker-compose --version
echo "docker install completed"

echo "
=============== Nextcloud ===============

"   
docker network create nextcloud_network

echo "enter parameters for nextcloud isntallation:"
read -p "Enter MYSQL_ROOT_PASSWORD: " MYSQL_ROOT_PASSWORD
read -p "Enter MYSQL_PASSWORD: " MYSQL_PASSWORD
read -p "Enter VIRTUAL_HOST: " VIRTUAL_HOST
read -p "Enter LETSENCRYPT_HOST: " LETSENCRYPT_HOST
read -p "Enter LETSENCRYPT_EMAIL: " LETSENCRYPT_EMAI

echo "writing docker compose file..."
echo "
version: '3' 

services:

  proxy:
    image: jwilder/nginx-proxy:alpine
    labels:
      - "com.github.jrcs.letsencrypt_nginx_proxy_companion.nginx_proxy=true"
    container_name: nextcloud-proxy
    networks:
      - nextcloud_network
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./proxy/conf.d:/etc/nginx/conf.d:rw
      - ./proxy/vhost.d:/etc/nginx/vhost.d:rw
      - ./proxy/html:/usr/share/nginx/html:rw
      - ./proxy/certs:/etc/nginx/certs:ro
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/tmp/docker.sock:ro
    restart: unless-stopped
  
  letsencrypt:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: nextcloud-letsencrypt
    depends_on:
      - proxy
    networks:
      - nextcloud_network
    volumes:
      - ./proxy/certs:/etc/nginx/certs:rw
      - ./proxy/vhost.d:/etc/nginx/vhost.d:rw
      - ./proxy/html:/usr/share/nginx/html:rw
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped

  db:
    image: mariadb
    container_name: nextcloud-mariadb
    networks:
      - nextcloud_network
    volumes:
      - db:/var/lib/mysql
      - /etc/localtime:/etc/localtime:ro
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
    restart: unless-stopped
  
  app:
    image: nextcloud:latest
    container_name: nextcloud-app
    networks:
      - nextcloud_network
    depends_on:
      - letsencrypt
      - proxy
      - db
    volumes:
      - nextcloud:/var/www/html
      - ./app/config:/var/www/html/config
      - ./app/custom_apps:/var/www/html/custom_apps
      - ./app/data:/var/www/html/data
      - ./app/themes:/var/www/html/themes
      - /etc/localtime:/etc/localtime:ro
    environment:
      - VIRTUAL_HOST=${VIRTUAL_HOST}
      - LETSENCRYPT_HOST=${LETSENCRYPT_HOST}
      - LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
    restart: unless-stopped

volumes:
  nextcloud:
  db:

networks:
  nextcloud_network:" > docker-compose.yaml

echo "running docker compose..."
docker-compose up -d
docker ps -a

echo "installation complete..."
exit 0