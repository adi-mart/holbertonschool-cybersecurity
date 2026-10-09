#!/bin/bash
wg genkey | tee serveur_private | wg pubkey > serveur_public
wg pubkey | tee server_public | wg genkey > server_private
