#!/bin/bash
scp ./wg0.conf /etc/wireguard/
wg-quick up wg0
wg-quick up client
ping 10.200.0.1
