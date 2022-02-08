#!/bin/sh

echo "Disable Firewal selinuxl"
systemctl stop firewalld && systemctl disable firewalld
sed -i s/SELINUX=enforcing/SELINUX=disabled/g /etc/selinux/config

echo "Install Start"
yum update -y
yum upgrade -y
yum install net-tools -y
yum install sshd -y
yum install curl -y
yum install wget -y
yum install vim -y
yum install git -y
yum install rpm -y
yum install -y epel-release -y
yum install java-1.8.0-openjdk-devel.x86_64 -y
yum install sshd -y


echo "PHP Install"
wget http://rpms.remirepo.net/enterprise/remi-release-7.rpm
rpm -Uvh remi-release-7.rpm
yum install yum-utils -y
yum-config-manager --enable remi-php71
yum --enablerepo=remi,remi-php71 install -y php-fpm php-common
yum --enablerepo=remi,remi-php71 install -y php-opcache php-pecl-apcu php-cli php-pear php-pdo php-mysqlnd php-pgsql php-pecl-mongodb php-pecl-redis php-pecl-memcache php-pecl-memcached php-gd php-mbstring php-mcrypt php-xml


echo "mariadb instll"
tee /etc/yum.repos.d/mariadb.repo <<-'EOF'
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.3/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF

yum install -y mariadb-server

systemctl start mysql

mysql_secure_installation <<EOF

y
passwd
passwd
y
y
y
y
EOF


tee /etc/my.cnf.d/mysql.cnf <<-'EOF'
[mysqld]
init_connect = SET collation_connection = utf8_general_ci
init_connect = SET NAMES utf8
character-set-server = utf8
collation-server = utf8_general_ci
character-set-client-handshake = FALSE
port = 7906
[mysqldump]
default-character-set = utf8
 
[mysql]
default-character-set = utf8
 
[client]
default-character-set = utf8

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid

EOF

tee /etc/my.cnf.d/query-cache.cnf <<-'EOF'
[mysqld]
query_cache_type = 1
query_cache_size = 16M
EOF




echo "nginx instll"
tee /etc/yum.repos.d/nginx.repo <<-'EOF'
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/$releasever/$basearch/
gpgcheck=0
enabled=1
EOF

yum install -y nginx

rm -r /etc/nginx/conf.d/default.conf

tee /etc/nginx/conf.d/default.conf <<-'EOF'
server {
    listen   80;
    server_name  your_server_ip;
 
    # note that these lines are originally from the "location /" block
    root   /usr/share/nginx/html;
    index index.php index.html index.htm;
 
    location / {
        try_files $uri $uri/ =404;
    }
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
 
    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass unix:/var/run/php-fpm/php-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF


tee /usr/share/nginx/html/index.php <<-'EOF'
<?php
phpinfo();
?>
EOF



sed -i 's/#Port\ 22/Port\ 7922/g' /etc/ssh/sshd_config
sed -i s/user\ =\ apache/user\ =\ nginx/g /etc/php-fpm.d/www.conf
sed -i s/group\ =\ apache/group\ =\ nginx/g /etc/php-fpm.d/www.conf
sudo sed -i -e "s/;listen.owner = nobody/listen.owner = nginx/g" /etc/php-fpm.d/www.conf
sudo sed -i -e "s/;listen.group = nobody/listen.group = nginx/g" /etc/php-fpm.d/www.conf
sudo sed -i -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm\/php-fpm.sock/g" /etc/php-fpm.d/www.conf
#sed -ie "s|listen = 127.0.0.1:9000|listen = /var/run/php-fpm/php-fpm.sock|g" /etc/php-fpm.d/www.conf

rm -r remi-release-7.rpm -y


echo "mariadb,php-fpm,ngix restart"

useradd -r -d /opt/wildfly/ -s /sbin/nologin wildfly


wget https://download.jboss.org/wildfly/20.0.1.Final/wildfly-20.0.1.Final.tar.gz -P /tmp

sudo tar xf /tmp/wildfly-20.0.1.Final.tar.gz -C /opt/


ln -s /opt/wildfly-20.0.1.Final/ /opt/wildfly


chown -Rf wildfly: $WILDFLY_HOME

chmod +x /opt/wildfly/bin/*.sh 



sudo chown -RH wildfly: /opt/wildfly
sudo mkdir -p /etc/wildfly
sudo cp /opt/wildfly/docs/contrib/scripts/systemd/wildfly.conf /etc/wildfly/
sudo cp /opt/wildfly/docs/contrib/scripts/systemd/launch.sh /opt/wildfly/bin/
sudo sh -c 'chmod +x /opt/wildfly/bin/*.sh'
sudo cp /opt/wildfly/docs/contrib/scripts/systemd/wildfly.service /etc/systemd/system/


#firewall-cmd --permanent --zone=public --add-port=8080/tcp
#firewall-cmd --permanent --zone=public --add-port=9990/tcp
#firewall-cmd --permanent --zone=public --add-port=7922/tcp
#firewall-cmd --permanent --zone=public --add-port=7906/tcp
#semanage port -a -t ssh_port_t -p tcp 7922
#semanage port -a -t mysqld_port_t -p tcp 7906
#semanage port -a -t wildfly_port_t -p tcp 8080
#semanage port -a -t wildflyadmin_port_t -p tcp 9990
#firewall-cmd --reload

sudo mkdir /var/run/wildfly/
sudo chown wildfly: /var/run/wildfly/


sudo systemctl daemon-reload
sudo systemctl enable mariadb
sudo systemctl enable php-fpm
sudo systemctl enable nginx
sudo systemctl enable wildfly
sudo systemctl restart wildfly
sudo systemctl restart mariadb
sudo systemctl restart php-fpm
sudo systemctl restart nginx

reboot
exit 0
