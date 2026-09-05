#!/bin/bash
if echo $(ip route get "$1") | grep -q "via"; then printf "REMOTE"; else printf "LOCAL"; fi
