#!/bin/bash
IFS='.' read -r IP1 IP2 IP3 IP4 <<< "$1"
IFS='.' read -r MASK1 MASK2 MASK3 MASK4 <<< "$2"

NET1=$((IP1 & MASK1))
NET2=$((IP2 & MASK2))
NET3=$((IP3 & MASK3))
NET4=$((IP4 & MASK4))

printf "%d.%d.%d.%d" "$NET1" "$NET2" "$NET3" "$NET4"
