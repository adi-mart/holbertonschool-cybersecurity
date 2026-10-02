#!/bin/bash
tshark -r "$1" --export-objects http,./objects
