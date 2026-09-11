#!/bin/bash
nmcli | awk '/servers/ {print $2}'
