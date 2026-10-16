#!/bin/bash
grep -i /var/log/squid/access\.log | sort | uniq -c | sort -nr | head  -10
