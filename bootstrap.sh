#!/bin/bash
yum update -y
yum install httpd -y
service httpd start
chkconfig httpd on
cd /var/www/html
echo "<html><body><h1>Hello World, this is my Apache Web Server</h1></body></html>" > index.html
