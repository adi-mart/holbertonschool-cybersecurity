#!/bin/bash
username=$1
public_key=$2

useradd -m "$username"
passwd -l "$username"
mkdir /home/"$username"/.ssh
chmod 700 /home/"$username"/.ssh
echo "$public_key" > /home/"$username"/.ssh/authorized_keys
chmod 600 /home/"$username"/.ssh/authorized_keys
chown -R "$username":"$username" /home/"$username"/.ssh
