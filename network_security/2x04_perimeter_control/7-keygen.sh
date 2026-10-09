#!/bin/bash
wg genkey | tee server_private | wg pubkey > server_public
wg pubkey | tee client_public | wg genkey > client_private
