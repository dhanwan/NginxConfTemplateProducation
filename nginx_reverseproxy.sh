#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo -e "\nPlease run as root\n"
  exit
fi

# Check for input

if [ $# -lt 2 ]; then
  echo -e "\nPlease provide a Port and Domain for proxy to forward v as an argument, e.g. ./install.sh 8080 domain.com\n"
  exit 1
fi

PORT=$1
DOMAIN_NAME=$2

echo -e "\n********** Installing Nginx ***********\n"
apt update
apt install -y nginx

# Directory for logs to store
mkdir -p /var/domlogs/nginx/

# Configure Nginx / Checking if domain name proxy exits or not 

if [ -f "/etc/nginx/sites-available/${DOMAIN_NAME}.conf" ]; then
  mv "/etc/nginx/sites-available/${DOMAIN_NAME}.conf" "/etc/nginx/sites-available/${DOMAIN_NAME}.conf.bak"
else
  echo "File /etc/nginx/sites-available/${DOMAIN_NAME}.conf does not exist"
fi

# creating Nginx ReverseConf file

cat > /etc/nginx/sites-available/${DOMAIN_NAME}.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    access_log /usr/local/apache/domlogs/domain.log combined;
    error_log /usr/local/apache/domlogs/domain.error.log error;

    location / {
        proxy_pass http://localhost:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        add_header X-Cache "HIT from Backend";
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
	add_header X-Frame-Options "SAMEORIGIN";
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ /\.svn/ {
        deny all;
    }

    location ~ /\.git/ {
        deny all;
    }

    location ~ /\.hg/ {
        deny all;
    }

    location ~ /\.bzr/ {
        deny all;
    }
}
EOF

echo -e "\n********** Nginx configuration is Done ***********\n"
