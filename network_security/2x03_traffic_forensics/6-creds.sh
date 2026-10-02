#!/bin/bash
tshark -r "$1" -T fields -e http.request.uri | grep -i "pass\|pwd\|password"
