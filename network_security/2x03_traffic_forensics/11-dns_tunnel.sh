#!/bin/bash
tshark -r "$1" -Y 'dns.qry.name.len > 50'
