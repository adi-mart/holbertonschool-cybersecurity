#!/bin/bash
until nc -z $1 80 2>/dev/null; do
	echo "Waiting..."
	sleep 1
done
echo "Service UP!"
