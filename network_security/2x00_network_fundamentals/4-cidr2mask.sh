#!/bin/bash
ipcalc "/$1" | awk 'NR==1 {print $2}'
