#!/bin/bash
file=$1
grep '\$1\$' "$file" | cut -d: -f1
