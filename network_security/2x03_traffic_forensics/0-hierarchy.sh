#!/bin/bash
tshark -z -r -q io, phs "$1"
