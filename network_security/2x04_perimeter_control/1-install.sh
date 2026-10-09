#!/bin/bash
apt install nftables
apt install wireguard wireguard-tools
systemctl enable nftables --no-start 
