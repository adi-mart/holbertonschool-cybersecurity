#!/bin/bash
for i in `echo $1 | tr '.' ' '`; do printf "%08d." "$(echo "obase=2;$i" | bc)"; done | sed 's/\.$//'
