#!/bin/bash
systemctl enable --no-start nftables
apt install nftables
apt install wireguard wireguard-tools
