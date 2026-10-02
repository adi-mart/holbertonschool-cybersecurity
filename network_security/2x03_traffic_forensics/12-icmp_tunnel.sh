#!/bin/bash
tshark -r "$1" -T fields -e icmp && data.len > 100
