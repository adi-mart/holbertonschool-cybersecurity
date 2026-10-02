#!/bin/bash
tshark -r "$1" -T fields -e http.request.uri contains "UNION SELECT"
