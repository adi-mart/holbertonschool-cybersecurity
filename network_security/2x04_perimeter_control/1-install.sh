#!/bin/bash
apt install nftables
systemctl enable --no-start nftables
apt install wireguard
apt isntall wireguard-tools
