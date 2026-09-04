#!/bin/bash
printf "%08/n"; (echo "obase=2;$1" | bc)
