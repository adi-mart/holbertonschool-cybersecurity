#!/bin/bash
tshark -r "$1" -Y '(ip.src == 10.10.10.50 && ip.dst == 172.16.42.66) || (ip.src == 172.16.42.66 && ip.dst == 10.10.10.50 )' -T fields -e frame.time
