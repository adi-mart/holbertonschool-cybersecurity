#!/bin/bash
grep '\$1\$' "$1" | cut -d: -f1
