#!/bin/bash
until nc -z $1 80 2>/dev/null; do
	echo "Waiting..."
done
echo "Service UP!"
