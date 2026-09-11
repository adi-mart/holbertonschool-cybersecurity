#!/bin/bash
awk '/localhost/ {print $1}' /etc/hosts | grep '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1\}'
