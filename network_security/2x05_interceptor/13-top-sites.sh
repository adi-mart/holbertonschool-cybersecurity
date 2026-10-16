#!/bin/bash
grep -i * access\.log  | sort | uniq -c | sort -nr | head  -10
