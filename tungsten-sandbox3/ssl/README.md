# Intro
Here are the certificates needed by the Mysql **server** and **client** to
enable SSL connection. The certificates was generated with the **mysslgen**
script.

## my.cnf
Supose the path where the certificates are installed is:  
CERT_PATH=/home/tungsten/sandboxes/tungsten_deployment/ssl

The following entries need to be added to my.cnf:

[client]
ssl-ca = /home/tungsten/sandboxes/tungsten_deployment/ssl/ca-cert.pem
ssl-cert = /home/tungsten/sandboxes/tungsten_deployment/ssl/client-cert.pem
ssl-key = /home/tungsten/sandboxes/tungsten_deployment/ssl/client-key.pem

[mysqld]
ssl-ca = /home/tungsten/sandboxes/tungsten_deployment/ssl/ca-cert.pem
ssl-cert = /home/tungsten/sandboxes/tungsten_deployment/ssl/server-cert.pem
ssl-key = /home/tungsten/sandboxes/tungsten_deployment/ssl/server-key.pem

## Importing the certificates to Tungsten keystore and trustore
keytool -import -alias mysql -file /home/tungsten/sandboxes/tungsten_deployment/ssl/ca-cert.pem -keystore /opt/continuent/share/tungsten_keystore.jks -storepass tungsten
keytool -import -alias mysql -file /home/tungsten/sandboxes/tungsten_deployment/ssl/ca-cert.pem -keystore /opt/continuent/share/tungsten_truststore.ts -storepass tungsten

## Creating an SSL user
grant all on *.* to tungsten_ssl@'%' identified by 'secret_ssl' require ssl with grant option;

## Tpm switch to enable SSL
tpm ... --datasource-enable-ssl={true|false} ...

## Verify that Mysql is configured with SSL
mysql [localhost] {tungsten_ssl} ((none)) > \s
...
SSL:            Cipher in use is DHE-RSA-AES256-SHA
...

