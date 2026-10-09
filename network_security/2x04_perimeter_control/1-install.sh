#!/bin/bash
apt install nftables
apt install wireguard wireguard-tools
systemctl enable --no-start nftables
