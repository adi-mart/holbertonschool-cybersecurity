#!/bin/bash
MASK=$((0xffffffff << (32 - "$1") & 0xffffffff)); echo "$(( (MASK >> 24) & 255 )).$(( (MASK >> 16) & 255 )).$(( (MASK >> 8) & 255 )).$(( MASK & 255 ))"