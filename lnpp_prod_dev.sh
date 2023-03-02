#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo -e "\nPlease run as root\n"
  exit
fi

if [ $# -lt 2 ]; then
  echo -e "\nPlease provide a PHP version as an argument, e.g. ./install.sh 7.4 domain.com\n"
  exit 1
fi

# Get the PHP version from the argument
PHP_VERSION=$1
DOMAIN_NAME=$2

# Progress Report with message
total_steps=3
current_step=0

echo -e "\nProgress: $((current_step * 100 / total_steps))%"
echo -e "\nStep $((++current_step)) of $total_steps: Starting process 1...\n"

# Add ondrej/php repository for PHP packages
echo -e "\n\t-------Installing required packages------\t\n"


echo -e "\t-------Wait for Packages to installed------\t\n"
sudo add-apt-repository ppa:ondrej/php -y >/dev/null 2>&1
sudo apt update >/dev/null 2>&1

apt install -y nginx php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip php${PHP_VERSION}-curl >/dev/null 2>&1

# Install MariaDB
apt install -y mariadb-server mariadb-client >/dev/null 2>&1


echo -e "\nProgress: $((current_step * 100 / total_steps))%\n"
echo "Step $((++current_step)) of $total_steps: Starting process 2..."
echo -e "\n\t-----Configuring nginx-------\t\n"




mkdir -p /var/domlogs/nginx/


# Configure Nginx

if [ -f "/etc/nginx/sites-available/${DOMAIN_NAME}.conf" ]; then
  mv "/etc/nginx/sites-available/${DOMAIN_NAME}.conf" "/etc/nginx/sites-available/${DOMAIN_NAME}.conf.bak"
else
  echo "File /etc/nginx/sites-available/${DOMAIN_NAME}.conf does not exist"
fi
# checking for Default conf

if [ -f "/etc/nginx/sites-enabled/default" ]; then
  echo "Disabling Default NGINX conf"
  unlink /etc/nginx/sites-enabled/default
fi

cat > /etc/nginx/sites-available/${DOMAIN_NAME}.conf <<EOF
# fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=CACHEZONE:10m inactive=60m max_size=40m;
# fastcgi_cache_key "\$scheme\$request_method\$host\$request_uri";
# add_header X-Cache "\$upstream_cache_status";
# server_tokens off;
#
server {
	listen 80 ;
	
	root /var/www/html;
	
        access_log /var/domlogs/nginx/${DOMAIN_NAME}.acccess.log combined;
        error_log /var/domlogs/nginx/${DOMAIN_NAME}.error.log error;



	# Add index.php to the list if you are using PHP
	index index.html index.htm index.php;
        
        
	server_name ${DOMAIN_NAME};
	include snippets/phpmyadmin.conf;

	

	location / {
		try_files \$uri \$uri/ /index.php?\$args;
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		#try_files \$uri \$uri/ =404;


	    # add_header X-Cache "HIT from Backend";
      	# add_header X-XSS-Protection "1; mode=block" always;
        # add_header X-Content-Type-Options "nosniff" always;
	    # add_header X-Frame-Options "SAMEORIGIN";


	}
	

	# pass PHP scripts to FastCGI server
	#
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
	#
	#	# With php-fpm (or other unix sockets):
		fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
	#	# With php-cgi (or other tcp sockets):
	#	fastcgi_pass 127.0.0.1:9000;
		# fastcgi_cache_min_uses 5;
		# fastcgi_cache_revalidate on;
		# fastcgi_cache_use_stale error timeout http_500;
		# fastcgi_cache CACHEZONE;
		# fastcgi_cache_valid  60m;
		# fastcgi_cache_background_update on;
		# fastcgi_cache_lock on;
	}
	
	# Deny Access 

	location ~ /\.ht    {deny all;}
        location ~ /\.svn/  {deny all;}
        location ~ /\.git/  {deny all;}
        location ~ /\.hg/   {deny all;}
        location ~ /\.bzr/  {deny all;}

	
}

EOF

if [ -f "/etc/nginx/sites-available/${DOMAIN_NAME}.conf" ]; then
	unlink /etc/nginx/sites-enabled/${DOMAIN_NAME}.conf 
	ln -s /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
else
	ln -s /etc/nginx/sites-available/${DOMAIN_NAME}.conf /etc/nginx/sites-enabled/
fi
# Configure phpMyAdmin
cat > /etc/nginx/snippets/phpmyadmin.conf <<EOF
location /phpmyadmin {
    root /usr/share/;
    index index.php index.html index.htm;

    location ~ ^/phpmyadmin/(.+\.php)$ {
        try_files \$uri =404;
        root /usr/share/;
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include /etc/nginx/fastcgi_params;
    }

    location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
        root /usr/share/;
    }
}
EOF

echo "Progress: $((current_step * 100 / total_steps))%"

# Restart Nginx and PHP-FPM

echo -e "\nStep $((++current_step)) of $total_steps: Starting process 3...\n"
echo -e "\t------Restarting nginx and php${PHP_VERSION}-fpm------\t\n"
systemctl restart nginx php${PHP_VERSION}-fpm

# Enable PHP-FPM on boot

systemctl enable php${PHP_VERSION}-fpm

systemctl restart nginx




#echo "nginx:- http://$DOMAIN_NAME/"
echo -e "\t\033[1;31mNginx:- http://$DOMAIN_NAME/\033[0m"
echo -e "\t\033[1;31mphpmyadmin:- http://$DOMAIN_NAME/phpmyadmin\033[0m\n"
#echo "phpmyadmin:- http://$DOMAIN_NAME/phpmyadmin"
echo -e "\nMake sure to install phpyadmin with the apt-get command\n"
echo -e "Progress: $((current_step * 100 / total_steps))%\n"
echo -e "All processes completed.\n"

echo -e "\t\n-----------Installation complete!-----------\n"
