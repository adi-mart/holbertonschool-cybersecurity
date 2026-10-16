#!/bin/bash
grep access\.log  | sort | uniq -c | sort -nr | head  -10
