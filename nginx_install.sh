#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [[ -n "$1" && -n "$2" ]]; then
  echo "Please provide a PHP version as an argument, e.g. ./install.sh 7.4 domain.com"
fi


# Get the PHP version from the argument
PHP_VERSION=$1
DOMAIN_NAME=$2

# Add ondrej/php repository for PHP packages
echo "Installing required packages..."
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

apt install -y nginx php${PHP_VERSION} php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip php${PHP_VERSION}-curl

# Install MariaDB
apt install -y mariadb-server mariadb-client

echo "Configuring nginx..."

mkdir -p /var/domlogs/nginx/
# touch /var/domlogs/nginx/${DOMAIN_NAME}.acccess.log
# touch /var/domlogs/nginx/${DOMAIN_NAME}.error.log

echo "Nginx Conf file creation......."
# Configure Nginx

if [ -f "/etc/nginx/sites-available/${DOMAIN_NAME}.conf" ]; then
  mv "/etc/nginx/sites-available/${DOMAIN_NAME}.conf" "/etc/nginx/sites-available/${DOMAIN_NAME}.conf.bak"
else
  echo "File /etc/nginx/sites-available/${DOMAIN_NAME}.conf does not exist"
fi

cat > /etc/nginx/sites-available/${DOMAIN_NAME}.conf <<EOF
fastcgi_cache_path /var/cache/nginx levels=1:2 keys_zone=CACHEZONE:10m inactive=60m max_size=40m;
fastcgi_cache_key "\$scheme\$request_method\$host\$request_uri";
add_header X-Cache "\$upstream_cache_status";
server_tokens off;
#
server {
	listen 80 ;
	
	root /var/www/html;
	
        access_log /var/domlogs/nginx/${DOMAIN_NAME}.acccess.log combined;
        error_log /var/domlogs/nginx${DOMAIN_NAME}.error.log error;



	# Add index.php to the list if you are using PHP
	index index.html index.htm index.php;
        
        
	server_name ${DOMAIN_NAME};
	include snippets/phpmyadmin.conf;

	

	location / {
		try_files \$uri \$uri/ /index.php?\$args;
		# First attempt to serve request as file, then
		# as directory, then fall back to displaying a 404.
		#try_files \$uri \$uri/ =404;


		add_header X-Cache "HIT from Backend";
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
		add_header X-Frame-Options "SAMEORIGIN";


	}
	

	# pass PHP scripts to FastCGI server
	#
	location ~ \.php$ {
		include snippets/fastcgi-php.conf;
	#
	#	# With php-fpm (or other unix sockets):
		fastcgi_pass unix:/var/run/php/php-fpm${PHP_VERSION}.sock;
	#	# With php-cgi (or other tcp sockets):
	#	fastcgi_pass 127.0.0.1:9000;
		fastcgi_cache_min_uses 5;
		fastcgi_cache_revalidate on;
		fastcgi_cache_use_stale error timeout http_500;
		fastcgi_cache CACHEZONE;
		fastcgi_cache_valid  60m;
		fastcgi_cache_background_update on;
		fastcgi_cache_lock on;
	}
	
	# Deny Access 

	location ~ /\.ht    {deny all;}
        location ~ /\.svn/  {deny all;}
        location ~ /\.git/  {deny all;}
        location ~ /\.hg/   {deny all;}
        location ~ /\.bzr/  {deny all;}

	
}

EOF

echo "Enable nginx site"
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

# Restart Nginx and PHP-FPM
echo "Restarting nginx and php-fpm..."
systemctl restart nginx php${PHP_VERSION}-fpm

# Enable PHP-FPM on boot

systemctl enable php${PHP_VERSION}-fpm

systemctl restart nginx

echo "Installation complete!"