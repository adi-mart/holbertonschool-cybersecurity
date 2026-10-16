#!/bin/bash
nft add rule $1 input '{
	tcp dport 3128 accept
	ip saddr 10.200.0.0/24 accept
}'
