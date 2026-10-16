#!/bin/bash
curl -x http://proxy_ip:3128 -o /dev/null -s -w "%{http_code}" http://blocked.malware.com | grep 403
