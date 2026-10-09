#!/bin/bash
wg genkey | tee serveur_private | wg pubkey > serveur_public
