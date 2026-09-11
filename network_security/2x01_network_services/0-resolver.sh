#!/bin/bash
awk '/nameserver/ {print $2}' /etc/resolv.conf
