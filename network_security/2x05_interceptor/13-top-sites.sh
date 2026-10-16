#!/bin/bash
grep -i * sites.log  | sort | uniq -c | sort -nr | head  -10
