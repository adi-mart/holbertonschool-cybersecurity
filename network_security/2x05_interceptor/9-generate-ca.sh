#!/bin/bash
mkdir /etc/squid/ssl_cert
openssl x509 -signkey domain.key -in domain.csr -req -days 365 -out domain.crt
ssl_db initialize
