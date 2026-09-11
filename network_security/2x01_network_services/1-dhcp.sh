#!/bin/bash
nmcli dhcp-server-identifier|DHCP4\.OPTION.*dhcp_server_identifier|DHCPACK|server identifier|server_identifier | awk '/servers/ {print $2}'
