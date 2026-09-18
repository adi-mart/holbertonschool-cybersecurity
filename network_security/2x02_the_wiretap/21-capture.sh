#!/bin/bash
sudo tcpdump -i wlan0 -w capture.pcap 'icmp and host 192.168.1.254 or tcp port 80 and host 192.168.1.123'
