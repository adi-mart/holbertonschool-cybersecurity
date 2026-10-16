#!/bin/bash
mkdir /etc/squid/ssl_cert
openssl x509 -signkey domain.key -in domain.csr -req -days 365 -out domain.crt
security_file_certgen -c -s /ssl_db
