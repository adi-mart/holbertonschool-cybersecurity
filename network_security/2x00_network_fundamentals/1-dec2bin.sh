#!/bin/bash
if [ "$1" >= 0 && "$1" <= 255 ]; then
	echo "obase=2;$1" | bc
fi
