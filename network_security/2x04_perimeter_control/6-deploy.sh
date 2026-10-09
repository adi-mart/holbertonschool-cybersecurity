#!/bin/bash
scp ./skeleton.con acme-gw01
./2-panic.sh
nft -f /etc/nftables.conf
nft list ruleset
