#!/bin/bash
traceroute -n "$1" | tail -n 1 | awk '{printf "%d", $1}'
