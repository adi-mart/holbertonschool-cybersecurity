#!/bin/bash
wg genkey | tee serveur.key | wg pubkey > serveur.pub
