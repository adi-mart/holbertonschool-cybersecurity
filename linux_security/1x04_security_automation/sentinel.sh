#!/bin/bash
[ -f "sentinel.conf" ] || exit 1; source "sentinel.conf"; [ -n "${SERVCIES+x}" ] && [ -n "${ILES_TO_WATCH+x}" ] || exit 1
